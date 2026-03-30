import ArgumentParser
import Foundation

public struct Export: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Export sessions to CSV."
    )

    @Option(name: .long, help: "Start date filter (yyyy-MM-dd).")
    var from: String?

    @Option(name: .long, help: "End date filter (yyyy-MM-dd).")
    var to: String?

    @Option(name: .long, help: "Filter by project name.")
    var project: String?

    @Option(name: .long, help: "Output file path (prints to stdout if omitted).")
    var output: String?

    @Flag(name: .long, help: "Include soft-deleted sessions.")
    var includeDeleted = false

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
        let csv = try store.exportCSV(from: fromDate, to: toDate, project: project, includeDeleted: includeDeleted)

        if let output = output {
            try csv.write(toFile: output, atomically: true, encoding: .utf8)
            print("Exported to \(output)")
        } else {
            print(csv)
        }
    }
}
