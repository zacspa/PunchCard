import ArgumentParser
import Foundation

public struct Delete: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Delete a session."
    )

    @Option(name: .long, help: "Session UUID (use `punchcard list --show-ids` to find it).")
    var id: String

    @Flag(name: .long, help: "Skip the Google Sheet sync for this delete.")
    var noSync: Bool = false

    public init() {}

    public func run() throws {
        guard let uuid = UUID(uuidString: id) else {
            throw ValidationError("Invalid session ID '\(id)'. Must be a UUID.")
        }

        let store = SessionStore()
        let session = try store.deleteSession(id: uuid)
        SyncDispatcher.pushBestEffort(session, noSync: noSync)

        print("Session deleted:")
        print("  ID:       \(session.id.uuidString)")
        print("  Project:  \(session.project)")
        print("  Started:  \(DateFormatting.formatDisplay(session.startTime))")
        if let hours = session.hours {
            print("  Hours:    \(String(format: "%.2f", hours))")
        }
        if let summary = session.summary {
            print("  Summary:  \(summary)")
        }
    }
}
