import Foundation

/// Reads billable expenses from the user's Google Sheet via the Apps Script
/// doGet endpoint. Uses the same webhook URL + shared secret that sync writes
/// use, so no new credentials are required beyond `punchcard config`.
public struct ExpenseFetchService {
    public static let requestTimeout: TimeInterval = 8
    public static let overallTimeout: TimeInterval = 12

    public struct RemoteExpense: Codable, Sendable {
        public let id: String
        public let project: String
        public let merchant: String
        public let amountCents: Int
        public let currency: String
        public let capturedAt: String
        public let category: String?
        public let billable: Bool
        public let note: String?
    }

    private struct ListResponse: Codable {
        let ok: Bool
        let expenses: [RemoteExpense]?
        let error: String?
    }

    public init() {}

    /// Fetch expenses from the sheet. Filters server-side by project + date +
    /// billable. Dates are inclusive; pass yyyy-MM-dd strings matching the
    /// invoice period.
    public func fetchBillable(
        project: String?,
        from: Date,
        to: Date
    ) throws -> [RemoteExpense] {
        let config = try SyncService().loadConfig()
        guard config.isConfigured else { throw SyncError.notConfigured }
        let url = try SyncService.validateHTTPSURL(config.webhookURL)

        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw SyncError.network("Webhook URL is not parseable.")
        }
        var items = comps.queryItems ?? []
        items.removeAll { $0.name == "secret" || $0.name == "resource" || $0.name == "project" || $0.name == "from" || $0.name == "to" || $0.name == "billable" }
        if let secret = config.sharedSecret, !secret.isEmpty {
            items.append(URLQueryItem(name: "secret", value: secret))
        }
        items.append(URLQueryItem(name: "resource", value: "expenses"))
        items.append(URLQueryItem(name: "billable", value: "1"))
        if let project = project {
            items.append(URLQueryItem(name: "project", value: project))
        }
        items.append(URLQueryItem(name: "from", value: DateFormatting.formatDateOnly(from)))
        items.append(URLQueryItem(name: "to", value: DateFormatting.formatDateOnly(to)))
        comps.queryItems = items

        guard let finalURL = comps.url else {
            throw SyncError.network("Could not build expenses URL.")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.requestTimeout

        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }

        let result = FetchResult()
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
        if semaphore.wait(timeout: .now() + Self.overallTimeout) == .timedOut {
            task.cancel()
            throw SyncError.network("Timed out fetching expenses after \(Int(Self.overallTimeout))s")
        }

        let snap = result.snapshot()
        if let err = snap.errorMessage {
            throw SyncError.network(err)
        }
        guard snap.status >= 200, snap.status < 300 else {
            let body = snap.body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            throw SyncError.badStatus(snap.status, body)
        }
        guard let data = snap.body else {
            throw SyncError.badResponse("Empty response body")
        }
        let decoder = JSONDecoder()
        let decoded: ListResponse
        do {
            decoded = try decoder.decode(ListResponse.self, from: data)
        } catch {
            let preview = String(data: data, encoding: .utf8)?.prefix(120) ?? ""
            throw SyncError.badResponse("Response was not JSON (looks like HTML or a login page): \(preview)")
        }
        if !decoded.ok {
            throw SyncError.badResponse("Server reported error: \(decoded.error ?? "unknown")")
        }
        return decoded.expenses ?? []
    }
}

private final class FetchResult: @unchecked Sendable {
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
