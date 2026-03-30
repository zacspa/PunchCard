import ArgumentParser
import Foundation

public struct Edit: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Edit a completed session."
    )

    @Option(name: .long, help: "Session UUID (use `punchcard list --show-ids` to find it).")
    var id: String

    @Option(name: .long, help: "Change the project name.")
    var project: String?

    @Option(name: .long, help: "Change the summary.")
    var summary: String?

    @Option(name: .long, help: "Change the end time (ISO 8601 format, e.g. 2026-03-30T17:00:00Z).")
    var endTime: String?

    public init() {}

    public func run() throws {
        guard let uuid = UUID(uuidString: id) else {
            throw ValidationError("Invalid session ID '\(id)'. Must be a UUID.")
        }

        // Validate project if changing it
        if let project = project {
            let projectStore = ProjectStore()
            guard try projectStore.validate(project) else {
                throw PunchCardError.invalidProject(project)
            }
        }

        // Parse end time if provided
        var parsedEndTime: Date? = nil
        if let endTime = endTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: endTime) else {
                throw ValidationError("Invalid --end-time '\(endTime)'. Use ISO 8601 format (e.g. 2026-03-30T17:00:00Z).")
            }
            parsedEndTime = date
        }

        guard project != nil || summary != nil || parsedEndTime != nil else {
            throw ValidationError("Nothing to edit. Provide at least one of --project, --summary, or --end-time.")
        }

        let store = SessionStore()
        let session = try store.editSession(
            id: uuid,
            project: project,
            summary: summary,
            endTime: parsedEndTime
        )

        print("Session updated:")
        print("  ID:       \(session.id.uuidString)")
        print("  Project:  \(session.project)")
        print("  Started:  \(DateFormatting.formatDisplay(session.startTime))")
        if let end = session.endTime {
            print("  Ended:    \(DateFormatting.formatDisplay(end))")
        }
        print("  Duration: \(session.formattedDuration)")
        if let summary = session.summary {
            print("  Summary:  \(summary)")
        }
    }
}
