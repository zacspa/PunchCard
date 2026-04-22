import Foundation

/// Posts session data to a user-configured webhook. Best-effort: network
/// failures enqueue the session to a local retry queue so the next successful
/// sync can flush them. The `stop` command never blocks for long and never
/// fails solely because sync failed.
public struct SyncService {
    public static let requestTimeout: TimeInterval = 5
    public static let overallTimeout: TimeInterval = 7
    public static let batchSize = 100

    private let configFile: URL
    private let queueFile: URL
    private let dataDir: URL

    public init() {
        self.dataDir = Paths.dataDir
        self.configFile = Paths.syncConfigFile
        self.queueFile = Paths.syncQueueFile
    }

    public init(directory: URL) {
        self.dataDir = directory
        self.configFile = directory.appendingPathComponent("sync.json")
        self.queueFile = directory.appendingPathComponent("sync-queue.json")
    }

    // MARK: - Config

    public func loadConfig() throws -> SyncConfig {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return SyncConfig()
        }
        let data = try Data(contentsOf: configFile)
        return try JSONDecoder().decode(SyncConfig.self, from: data)
    }

    public func saveConfig(_ config: SyncConfig) throws {
        try Paths.ensureDirectoryExists(dataDir)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try writeRestricted(data: data, to: configFile)
    }

    // MARK: - Retry queue

    public func loadQueue() throws -> [String] {
        guard FileManager.default.fileExists(atPath: queueFile.path) else {
            return []
        }
        let data = try Data(contentsOf: queueFile)
        return try JSONDecoder().decode([String].self, from: data)
    }

    public func saveQueue(_ ids: [String]) throws {
        try Paths.ensureDirectoryExists(dataDir)
        if ids.isEmpty {
            try? FileManager.default.removeItem(at: queueFile)
            return
        }
        let data = try JSONEncoder().encode(ids)
        try writeRestricted(data: data, to: queueFile)
    }

    public func enqueueFailure(sessionID: UUID) throws {
        var ids = (try? loadQueue()) ?? []
        let s = sessionID.uuidString
        if !ids.contains(s) {
            ids.append(s)
            try saveQueue(ids)
        }
    }

    /// Writes data with owner-only permissions (0o600) atomically. Creates the
    /// file with restricted perms up front so there is no brief 0o644 window.
    private func writeRestricted(data: Data, to url: URL) throws {
        let fm = FileManager.default
        // Write to a temp file with 0o600, then rename into place.
        let tmp = url.appendingPathExtension("tmp")
        if fm.fileExists(atPath: tmp.path) {
            try fm.removeItem(at: tmp)
        }
        let created = fm.createFile(atPath: tmp.path, contents: data, attributes: [.posixPermissions: 0o600])
        guard created else {
            throw SyncError.localIO("Failed to create \(tmp.path)")
        }
        if fm.fileExists(atPath: url.path) {
            _ = try? fm.replaceItemAt(url, withItemAt: tmp)
        } else {
            try fm.moveItem(at: tmp, to: url)
        }
        // Belt-and-suspenders in case replaceItemAt copied default attrs from old.
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    // MARK: - Payload

    public struct SessionPayload: Codable, Sendable {
        public let id: String
        public let project: String
        public let startTime: String
        public let endTime: String?
        public let hours: Double?
        public let summary: String?
        public let notes: [String]
        public let commits: [String]
        public let deleted: Bool
    }

    public struct ReplaceScope: Codable, Sendable {
        public let from: String?
        public let to: String?
        public let project: String?
        public let includeDeleted: Bool

        public init(from: String? = nil, to: String? = nil, project: String? = nil, includeDeleted: Bool = false) {
            self.from = from
            self.to = to
            self.project = project
            self.includeDeleted = includeDeleted
        }
    }

    public static func makePayload(_ session: Session) -> SessionPayload {
        SessionPayload(
            id: session.id.uuidString,
            project: session.project,
            startTime: DateFormatting.formatISO8601(session.startTime),
            endTime: session.endTime.map(DateFormatting.formatISO8601),
            hours: session.hours,
            summary: session.summary,
            notes: session.notes,
            commits: session.commits,
            deleted: session.isDeleted
        )
    }

    // MARK: - Post

    /// Push a single session as an upsert. On any failure, record the session
    /// ID in the retry queue so `punchcard sync --flush-queue` can retry it.
    /// Returns the HTTP status on success; throws on failure.
    @discardableResult
    public func push(_ session: Session, action: String = "upsert") throws -> Int {
        let config = try loadConfig()
        guard config.isConfigured else { throw SyncError.notConfigured }
        let url = try Self.validateHTTPSURL(config.webhookURL)
        let payload = [Self.makePayload(session)]
        let envelope: [String: Any] = [
            "action": action,
            "sessions": payload.map(Self.payloadDict),
        ]
        return try post(url: url, secret: config.sharedSecret, body: envelope)
    }

    /// Build the envelopes that `pushAll` would POST, without sending them.
    /// Each element is one HTTP body (batched per `batchSize`).
    public func buildEnvelopes(
        _ sessions: [Session],
        action: String = "upsert",
        replaceScope: ReplaceScope? = nil
    ) -> [[String: Any]] {
        if sessions.isEmpty {
            if action == "replace", let scope = replaceScope {
                var envelope: [String: Any] = [
                    "action": "replace",
                    "sessions": [[String: Any]](),
                ]
                envelope["scope"] = Self.scopeDict(scope)
                return [envelope]
            }
            return []
        }
        let chunks = stride(from: 0, to: sessions.count, by: Self.batchSize).map {
            Array(sessions[$0..<min($0 + Self.batchSize, sessions.count)])
        }
        var envelopes: [[String: Any]] = []
        for (index, chunk) in chunks.enumerated() {
            var envelope: [String: Any] = [
                "action": action,
                "sessions": chunk.map { Self.payloadDict(Self.makePayload($0)) },
            ]
            if action == "replace", index == 0, let scope = replaceScope {
                envelope["scope"] = Self.scopeDict(scope)
            } else if action == "replace" {
                envelope["action"] = "upsert"
            }
            envelopes.append(envelope)
        }
        return envelopes
    }

    /// Push multiple sessions. Batches to `batchSize` per request. Returns the
    /// last HTTP status on success; throws on first failure.
    @discardableResult
    public func pushAll(
        _ sessions: [Session],
        action: String = "upsert",
        replaceScope: ReplaceScope? = nil
    ) throws -> Int {
        let config = try loadConfig()
        guard config.isConfigured else { throw SyncError.notConfigured }
        let url = try Self.validateHTTPSURL(config.webhookURL)

        if sessions.isEmpty {
            // Still honor a scoped replace with an empty payload (pure delete).
            if action == "replace", let scope = replaceScope {
                var envelope: [String: Any] = [
                    "action": "replace",
                    "sessions": [[String: Any]](),
                ]
                envelope["scope"] = Self.scopeDict(scope)
                return try post(url: url, secret: config.sharedSecret, body: envelope)
            }
            return 200
        }

        var lastStatus = 0
        let chunks = stride(from: 0, to: sessions.count, by: Self.batchSize).map {
            Array(sessions[$0..<min($0 + Self.batchSize, sessions.count)])
        }

        for (index, chunk) in chunks.enumerated() {
            var envelope: [String: Any] = [
                "action": action,
                "sessions": chunk.map { Self.payloadDict(Self.makePayload($0)) },
            ]
            // Replace scope only applies on the first chunk; later chunks upsert.
            if action == "replace", index == 0, let scope = replaceScope {
                envelope["scope"] = Self.scopeDict(scope)
            } else if action == "replace" {
                envelope["action"] = "upsert"
            }
            lastStatus = try post(url: url, secret: config.sharedSecret, body: envelope)
        }
        return lastStatus
    }

    private static func payloadDict(_ p: SessionPayload) -> [String: Any] {
        var d: [String: Any] = [
            "id": p.id,
            "project": p.project,
            "startTime": p.startTime,
            "notes": p.notes,
            "commits": p.commits,
            "deleted": p.deleted,
        ]
        if let end = p.endTime { d["endTime"] = end }
        if let hours = p.hours { d["hours"] = hours }
        if let summary = p.summary { d["summary"] = summary }
        return d
    }

    private static func scopeDict(_ s: ReplaceScope) -> [String: Any] {
        var d: [String: Any] = ["includeDeleted": s.includeDeleted]
        if let f = s.from { d["from"] = f }
        if let t = s.to { d["to"] = t }
        if let p = s.project { d["project"] = p }
        return d
    }

    /// Post a single expense payload as `upsert-expenses`. Uses a longer
    /// overall timeout than session syncs because the payload may include a
    /// base64-encoded receipt image.
    @discardableResult
    public func postExpense(_ expense: [String: Any]) throws -> Int {
        let config = try loadConfig()
        guard config.isConfigured else { throw SyncError.notConfigured }
        let url = try Self.validateHTTPSURL(config.webhookURL)
        let envelope: [String: Any] = [
            "action": "upsert-expenses",
            "expenses": [expense],
        ]
        return try post(url: url, secret: config.sharedSecret, body: envelope, overallTimeout: 20)
    }

    private func post(url: URL, secret: String?, body: [String: Any], overallTimeout: TimeInterval = Self.overallTimeout) throws -> Int {
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        // Apps Script web apps can't reliably read custom request headers, so
        // we also carry the secret as a query parameter. Neither channel is
        // written to the JSON body (which Apps Script logs verbatim).
        let finalURL: URL = {
            guard let secret = secret, !secret.isEmpty else { return url }
            guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
            var items = comps.queryItems ?? []
            items.removeAll { $0.name == "secret" }
            items.append(URLQueryItem(name: "secret", value: secret))
            comps.queryItems = items
            return comps.url ?? url
        }()
        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret = secret, !secret.isEmpty {
            request.setValue(secret, forHTTPHeaderField: "X-PunchCard-Secret")
        }
        request.httpBody = jsonData
        request.timeoutInterval = Self.requestTimeout

        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }

        let result = PostResult()
        let semaphore = DispatchSemaphore(value: 0)

        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error = error {
                result.set(errorMessage: error.localizedDescription)
                return
            }
            if let http = response as? HTTPURLResponse {
                result.set(status: http.statusCode, body: data)
            }
        }
        task.resume()
        let waitResult = semaphore.wait(timeout: .now() + overallTimeout)
        if waitResult == .timedOut {
            task.cancel()
            throw SyncError.network("Timed out after \(Int(overallTimeout))s")
        }

        let snapshot = result.snapshot()
        if let errorMessage = snapshot.errorMessage {
            throw SyncError.network(errorMessage)
        }
        if snapshot.status < 200 || snapshot.status >= 300 {
            let msg = snapshot.body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw SyncError.badStatus(snapshot.status, msg)
        }
        // Defend against 200-with-HTML (misconfigured / revoked Apps Script).
        guard let data = snapshot.body else {
            throw SyncError.badStatus(snapshot.status, "Empty response body")
        }
        let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dict = parsed else {
            let preview = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
            throw SyncError.badResponse("Response was not JSON (looks like HTML or a login page): \(preview)")
        }
        if let ok = dict["ok"] as? Bool, ok { return snapshot.status }
        // Accept some responses that don't set `ok` but signal success another way.
        if let error = dict["error"] as? String {
            throw SyncError.badResponse("Server reported error: \(error)")
        }
        throw SyncError.badResponse("Response JSON did not include ok:true — \(dict)")
    }

    public static func validateHTTPSURL(_ string: String?) throws -> URL {
        guard let s = string, !s.isEmpty else { throw SyncError.notConfigured }
        guard let url = URL(string: s) else {
            throw SyncError.network("Webhook URL is not parseable: \(s)")
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
            throw SyncError.network("Webhook URL must use https (got '\(url.scheme ?? "none")').")
        }
        guard url.host != nil else {
            throw SyncError.network("Webhook URL must include a host.")
        }
        return url
    }
}

public enum SyncError: Error, CustomStringConvertible, Equatable {
    case notConfigured
    case network(String)
    case badStatus(Int, String)
    case badResponse(String)
    case localIO(String)

    public var description: String {
        switch self {
        case .notConfigured:
            return "Sheet sync is not configured. Run `punchcard config set-webhook <URL>` first."
        case .network(let msg):
            return "Sheet sync network error: \(msg)"
        case .badStatus(let code, let body):
            let snippet = body.prefix(200)
            return "Sheet sync failed (HTTP \(code)): \(snippet)"
        case .badResponse(let msg):
            return "Sheet sync rejected response: \(msg)"
        case .localIO(let msg):
            return "Sheet sync local I/O error: \(msg)"
        }
    }
}

/// Thread-safe result holder for the URLSession completion callback.
/// Keeps mutation off captured local vars so Swift 6 concurrency checking
/// passes without `@unchecked Sendable` on the closure itself.
private final class PostResult: @unchecked Sendable {
    private let lock = NSLock()
    private var _status: Int = -1
    private var _body: Data?
    private var _errorMessage: String?

    struct Snapshot {
        var status: Int
        var body: Data?
        var errorMessage: String?
    }

    func set(status: Int, body: Data?) {
        lock.lock(); defer { lock.unlock() }
        _status = status
        _body = body
    }

    func set(errorMessage: String) {
        lock.lock(); defer { lock.unlock() }
        _errorMessage = errorMessage
    }

    func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(status: _status, body: _body, errorMessage: _errorMessage)
    }
}
