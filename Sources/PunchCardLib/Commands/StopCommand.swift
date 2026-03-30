import ArgumentParser
import Foundation

public struct Stop: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Stop the active work session."
    )

    @Option(name: .long, help: "Summary of work done.")
    var summary: String?

    @Option(name: .long, help: "Path to a file containing the summary (avoids shell escaping issues).")
    var summaryFile: String?

    @Option(name: .long, help: "Comma-separated or newline-separated commit summaries.")
    var commits: String?

    @Option(name: .long, help: "Path to a file containing commit summaries (one per line).")
    var commitsFile: String?

    public init() {}

    public func run() throws {
        // Resolve summary: prefer --summary-file over --summary
        let resolvedSummary: String
        if let file = summaryFile {
            resolvedSummary = try String(contentsOfFile: file, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let summary = summary {
            resolvedSummary = summary
        } else {
            throw ValidationError("Either --summary or --summary-file is required.")
        }

        // Resolve commits: prefer --commits-file over --commits
        let commitList: [String]
        if let file = commitsFile {
            let contents = try String(contentsOfFile: file, encoding: .utf8)
            commitList = contents
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else if let commits = commits, !commits.isEmpty {
            commitList = commits
                .components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",")))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } else {
            commitList = []
        }

        let store = SessionStore()
        let session = try store.stopSession(summary: resolvedSummary, commits: commitList)
        print("Session stopped for '\(session.project)'")
        print("Duration: \(session.formattedDuration)")
        if let hours = session.hours {
            print("Hours: \(String(format: "%.2f", hours))")
        }
        if !commitList.isEmpty {
            print("Commits captured: \(commitList.count)")
        }
    }
}
