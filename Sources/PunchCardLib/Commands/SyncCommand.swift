import ArgumentParser
import Foundation

public struct Sync: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Push sessions to the configured Google Sheet webhook."
    )

    @Option(name: .long, help: "Only sync sessions on or after this date (yyyy-MM-dd).")
    var from: String?

    @Option(name: .long, help: "Only sync sessions on or before this date (yyyy-MM-dd).")
    var to: String?

    @Option(name: .long, help: "Only sync sessions for this project.")
    var project: String?

    @Flag(name: .long, help: "Include soft-deleted sessions in the push (for reconciliation).")
    var includeDeleted: Bool = false

    @Flag(name: .long, help: "Replace rows in the filter scope on the remote sheet before appending. Deletes rows outside the local payload.")
    var replace: Bool = false

    @Flag(name: .long, help: "Only flush sessions queued after prior sync failures (ignores other filters).")
    var flushQueue: Bool = false

    @Flag(name: .long, help: "Print the request envelopes instead of POSTing — use to verify config without hitting the network.")
    var dryRun: Bool = false

    public init() {}

    public func run() throws {
        if flushQueue {
            try runFlushQueue()
            return
        }

        let fromDate = try parseDate(from, label: "--from")
        let toDate = try parseDate(to, label: "--to")

        let store = SessionStore()
        let data = try store.loadSessions()

        let sessions = data.sessions.filter { session in
            if session.isActive { return false }
            if !includeDeleted && session.isDeleted { return false }
            if let fromDate = fromDate, session.startTime < fromDate { return false }
            if let toDate = toDate {
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: toDate) ?? toDate
                if session.startTime >= endOfDay { return false }
            }
            if let project = project, session.project != project { return false }
            return true
        }

        if sessions.isEmpty && !replace {
            print("No sessions match the filter — nothing to sync.")
            return
        }

        let sync = SyncService()
        let scope = replace
            ? SyncService.ReplaceScope(
                from: from,
                to: to,
                project: project,
                includeDeleted: includeDeleted
            )
            : nil

        if dryRun {
            try printDryRun(sync: sync, sessions: sessions, scope: scope)
            return
        }

        let status = try sync.pushAll(
            sessions,
            action: replace ? "replace" : "upsert",
            replaceScope: scope
        )
        let label = replace ? "replaced" : "upserted"
        print("Pushed \(sessions.count) session\(sessions.count == 1 ? "" : "s") (\(label), HTTP \(status)).")

        // Opportunistic: flush the failure queue after a successful push.
        try? flushQueueQuietly()
    }

    private func printDryRun(sync: SyncService, sessions: [Session], scope: SyncService.ReplaceScope?) throws {
        let config = try sync.loadConfig()
        let url: URL
        do {
            url = try SyncService.validateHTTPSURL(config.webhookURL)
        } catch {
            throw ValidationError("Webhook is not configured or invalid: \(error)")
        }
        let envelopes = sync.buildEnvelopes(
            sessions,
            action: replace ? "replace" : "upsert",
            replaceScope: scope
        )
        let secretMarker = (config.sharedSecret?.isEmpty == false)
            ? "present (\(config.sharedSecret!.count) chars)" : "none"
        let redactedHost = url.host ?? "?"
        let redactedURL = "\(url.scheme ?? "?")://\(redactedHost)/…\(url.absoluteString.suffix(6))"
        print("DRY RUN — no network call will be made.")
        print("Method:  POST")
        print("URL:     \(redactedURL)  (use `punchcard config show --reveal` for full)")
        print("Headers:")
        print("  Content-Type: application/json")
        print("  X-PunchCard-Secret: \(secretMarker)")
        print("Query:   secret=\(secretMarker == "none" ? "<omitted>" : "<same>")")
        print("Batches: \(envelopes.count)   Sessions: \(sessions.count)")
        print("")
        for (i, env) in envelopes.enumerated() {
            print("--- Batch \(i + 1)/\(envelopes.count) ---")
            let data = try JSONSerialization.data(withJSONObject: env, options: [.prettyPrinted, .sortedKeys])
            if let s = String(data: data, encoding: .utf8) {
                print(s)
            }
        }
    }

    private func runFlushQueue() throws {
        let sync = SyncService()
        let queuedIDs = Set((try? sync.loadQueue()) ?? [])
        if queuedIDs.isEmpty {
            print("Retry queue is empty.")
            return
        }
        let store = SessionStore()
        let data = try store.loadSessions()
        let sessions = data.sessions.filter {
            queuedIDs.contains($0.id.uuidString) && !$0.isActive
        }
        if sessions.isEmpty {
            try sync.saveQueue([]) // queue references sessions that no longer exist
            print("Queue contained only stale IDs — cleared.")
            return
        }
        let status = try sync.pushAll(sessions, action: "upsert")
        try sync.saveQueue([]) // all flushed
        print("Flushed \(sessions.count) queued session\(sessions.count == 1 ? "" : "s") (HTTP \(status)).")
    }

    private func flushQueueQuietly() throws {
        let sync = SyncService()
        let queuedIDs = Set((try? sync.loadQueue()) ?? [])
        if queuedIDs.isEmpty { return }
        let store = SessionStore()
        let data = try store.loadSessions()
        let sessions = data.sessions.filter {
            queuedIDs.contains($0.id.uuidString) && !$0.isActive
        }
        if sessions.isEmpty {
            try? sync.saveQueue([])
            return
        }
        if (try? sync.pushAll(sessions, action: "upsert")) != nil {
            try? sync.saveQueue([])
        }
    }

    private func parseDate(_ value: String?, label: String) throws -> Date? {
        guard let value = value else { return nil }
        guard let date = DateFormatting.parseDate(value) else {
            throw ValidationError("Invalid \(label) '\(value)'. Use yyyy-MM-dd.")
        }
        return date
    }
}
