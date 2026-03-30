import ArgumentParser
import Foundation

public struct List: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "List completed work sessions."
    )

    @Option(name: .long, help: "Start date filter (yyyy-MM-dd).")
    var from: String?

    @Option(name: .long, help: "End date filter (yyyy-MM-dd).")
    var to: String?

    @Option(name: .long, help: "Filter by project name.")
    var project: String?

    @Flag(name: .long, help: "Show session IDs (for use with edit/delete).")
    var showIds = false

    public init() {}

    public func run() throws {
        var fromDate: Date? = nil
        if let from = from {
            guard let parsed = DateFormatting.parseDate(from) else {
                throw ValidationError("Invalid --from date '\(from)'. Use yyyy-MM-dd format.")
            }
            fromDate = parsed
        }
        var toDate: Date? = nil
        if let to = to {
            guard let parsed = DateFormatting.parseDate(to) else {
                throw ValidationError("Invalid --to date '\(to)'. Use yyyy-MM-dd format.")
            }
            toDate = parsed
        }

        let store = SessionStore()
        let sessions = try store.listSessions(from: fromDate, to: toDate, project: project)

        if sessions.isEmpty {
            print("No sessions found.")
            return
        }

        // Table header
        print("\("Date".padding(toLength: 12, withPad: " ", startingAt: 0))  \("Hours".padding(toLength: 6, withPad: " ", startingAt: 0))  \("Project".padding(toLength: 15, withPad: " ", startingAt: 0))  Summary")
        print(String(repeating: "-", count: 72))

        var totalHours: Double = 0
        for session in sessions {
            let date = DateFormatting.formatDateOnly(session.startTime)
            let hours = session.hours ?? 0
            totalHours += hours
            let hoursStr = String(format: "%.2f", hours)
            let proj = String(session.project.prefix(15))
            let notesSuffix = session.notes.isEmpty ? "" : " [\(session.notes.count) notes]"
            let summaryBase = session.summary ?? session.notes.first ?? "-"
            let maxLen = 50 - notesSuffix.count
            let summaryTruncated = String(summaryBase.prefix(max(10, maxLen))) + notesSuffix
            var line = "\(date.padding(toLength: 12, withPad: " ", startingAt: 0))  \(hoursStr.padding(toLength: 6, withPad: " ", startingAt: 0))  \(proj.padding(toLength: 15, withPad: " ", startingAt: 0))  \(summaryTruncated)"
            if showIds {
                line += "\n    ID: \(session.id.uuidString)"
            }
            print(line)
        }

        print(String(repeating: "-", count: 72))
        print("Total: \(String(format: "%.2f", totalHours)) hours across \(sessions.count) sessions")
    }
}
