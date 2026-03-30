import ArgumentParser
import Foundation

public struct Undelete: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Restore a soft-deleted session."
    )

    @Option(name: .long, help: "Session UUID to restore.")
    var id: String

    public init() {}

    public func run() throws {
        guard let uuid = UUID(uuidString: id) else {
            throw ValidationError("Invalid session ID '\(id)'. Must be a UUID.")
        }

        let store = SessionStore()
        let session = try store.undeleteSession(id: uuid)

        print("Session restored:")
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
