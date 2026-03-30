import ArgumentParser
import Foundation

public struct Status: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Show the active session status."
    )

    public init() {}

    public func run() throws {
        let store = SessionStore()
        guard let session = try store.activeSession() else {
            print("No active session.")
            return
        }

        print("Active session:")
        print("  Project:  \(session.project)")
        print("  Started:  \(DateFormatting.formatDisplay(session.startTime))")
        print("  Elapsed:  \(session.formattedDuration)")
        print("  ISO8601:  \(DateFormatting.formatISO8601(session.startTime))")
        if !session.notes.isEmpty {
            print("  Notes:    \(session.notes.count)")
            for note in session.notes {
                print("    - \(note)")
            }
        }
    }
}
