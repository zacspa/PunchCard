import ArgumentParser
import Foundation

public struct Start: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Start a new work session."
    )

    @Option(name: .long, help: "Project name (must be registered).")
    var project: String

    public init() {}

    public func run() throws {
        let projectStore = ProjectStore()
        guard try projectStore.validate(project) else {
            throw PunchCardError.invalidProject(project)
        }

        let store = SessionStore()
        let session = try store.startSession(project: project)
        print("Session started for '\(session.project)' at \(DateFormatting.formatDisplay(session.startTime))")
    }
}
