import ArgumentParser
import Foundation

public struct Start: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Start a new work session."
    )

    @Option(name: .long, help: "Project name (must be registered).")
    var project: String

    @Option(name: .long, help: "Backdate the start time. Accepts \"09:15\", \"12:00pm\", \"2026-04-18 09:00\", or ISO 8601.")
    var at: String?

    @Option(name: .long, help: "Backdate by a relative duration, e.g. \"30m\", \"1h\", \"1h30m\".")
    var ago: String?

    public init() {}

    public func run() throws {
        let projectStore = ProjectStore()
        guard try projectStore.validate(project) else {
            throw PunchCardError.invalidProject(project)
        }

        let startTime = try resolveStartTime()

        let store = SessionStore()
        let session = try store.startSession(project: project, startTime: startTime)
        print("Session started for '\(session.project)' at \(DateFormatting.formatDisplay(session.startTime))")
    }

    private func resolveStartTime() throws -> Date {
        if at != nil && ago != nil {
            throw ValidationError("Pass either --at or --ago, not both.")
        }
        if let atValue = at {
            guard let parsed = TimeParser.parseAt(atValue) else {
                throw ValidationError("Could not parse --at '\(atValue)'. Try \"09:15\", \"12:00pm\", \"2026-04-18 09:00\", or ISO 8601.")
            }
            return parsed
        }
        if let agoValue = ago {
            guard let seconds = TimeParser.parseDuration(agoValue) else {
                throw ValidationError("Could not parse --ago '\(agoValue)'. Try \"30m\", \"1h\", or \"1h30m\".")
            }
            return Date().addingTimeInterval(-seconds)
        }
        return Date()
    }
}
