import Foundation

/// Posts session data to a user-configured webhook (e.g. a Google Apps Script
/// bound to a Sheet). Intentionally best-effort: sync failures should print a
/// warning but never block a stop/edit from persisting locally.
public struct SyncService {
    private let configFile: URL
    private let dataDir: URL

    public init() {
        self.dataDir = Paths.dataDir
        self.configFile = Paths.syncConfigFile
    }

    public init(directory: URL) {
        self.dataDir = directory
        self.configFile = directory.appendingPathComponent("sync.json")
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
        try data.write(to: configFile, options: .atomic)
        // Tighten permissions — file contains the webhook URL / shared secret.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configFile.path)
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

    /// Post a single session to the webhook. Returns the HTTP status; throws on
    /// network / encoding errors.
    @discardableResult
    public func push(_ session: Session, action: String = "upsert") throws -> Int {
        let config = try loadConfig()
        guard config.isConfigured else {
            throw SyncError.notConfigured
        }
        return try post(
            url: URL(string: config.webhookURL!)!,
            secret: config.sharedSecret,
            body: [
                "action": action,
                "secret": config.sharedSecret as Any,
                "sessions": [Self.makePayload(session)],
            ].compactMapValues { $0 is NSNull ? nil : $0 }
        )
    }

    /// Post multiple sessions in one request (used by `punchcard sync`).
    @discardableResult
    public func pushAll(_ sessions: [Session], action: String = "replace") throws -> Int {
        let config = try loadConfig()
        guard config.isConfigured else {
            throw SyncError.notConfigured
        }
        let payload = sessions.map(Self.makePayload)
        return try post(
            url: URL(string: config.webhookURL!)!,
            secret: config.sharedSecret,
            body: [
                "action": action,
                "secret": config.sharedSecret as Any,
                "sessions": payload,
            ].compactMapValues { $0 is NSNull ? nil : $0 }
        )
    }

    private func post(url: URL, secret: String?, body: [String: Any]) throws -> Int {
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let secret = secret, !secret.isEmpty {
            request.setValue(secret, forHTTPHeaderField: "X-PunchCard-Secret")
        }
        request.httpBody = jsonData
        request.timeoutInterval = 15

        let result = PostResult()
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
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
        _ = semaphore.wait(timeout: .now() + 20)

        let snapshot = result.snapshot()
        if let errorMessage = snapshot.errorMessage {
            throw SyncError.network(errorMessage)
        }
        if snapshot.status < 200 || snapshot.status >= 300 {
            let msg = snapshot.body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw SyncError.badStatus(snapshot.status, msg)
        }
        return snapshot.status
    }
}

/// Thread-safe result holder for the URLSession completion callback.
/// Keeps mutation off captured local vars so the Swift 6 concurrency checker
/// can prove the closure is Sendable.
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

public enum SyncError: Error, CustomStringConvertible, Equatable {
    case notConfigured
    case network(String)
    case badStatus(Int, String)

    public var description: String {
        switch self {
        case .notConfigured:
            return "Sheet sync is not configured. Run `punchcard config set-webhook <URL>` first."
        case .network(let msg):
            return "Sheet sync network error: \(msg)"
        case .badStatus(let code, let body):
            let snippet = body.prefix(200)
            return "Sheet sync failed (HTTP \(code)): \(snippet)"
        }
    }
}
