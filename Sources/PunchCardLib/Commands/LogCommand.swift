import ArgumentParser
import Foundation

public struct Log: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Add a note to the active session."
    )

    @Argument(help: "Note to add to the current session.")
    var note: String

    public init() {}

    public func run() throws {
        let store = SessionStore()
        let session = try store.addNote(note)
        print("Note added to '\(session.project)' session. (\(session.notes.count) total notes)")
    }
}
