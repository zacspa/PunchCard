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

    @Flag(name: .long, help: "Send 'replace' so the remote clears rows in scope before appending. Default is 'upsert'.")
    var replace: Bool = false

    public init() {}

    public func run() throws {
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

        if sessions.isEmpty {
            print("No sessions match the filter — nothing to sync.")
            return
        }

        let sync = SyncService()
        let status = try sync.pushAll(sessions, action: replace ? "replace" : "upsert")
        print("Pushed \(sessions.count) session\(sessions.count == 1 ? "" : "s") (HTTP \(status)).")
    }

    private func parseDate(_ value: String?, label: String) throws -> Date? {
        guard let value = value else { return nil }
        guard let date = DateFormatting.parseDate(value) else {
            throw ValidationError("Invalid \(label) '\(value)'. Use yyyy-MM-dd.")
        }
        return date
    }
}
