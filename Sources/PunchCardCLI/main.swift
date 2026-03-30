import ArgumentParser
import PunchCardLib

struct PunchCardCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "punchcard",
        abstract: "Time tracking and invoicing for contract work.",
        subcommands: [
            Start.self,
            Stop.self,
            Log.self,
            Status.self,
            List.self,
            Edit.self,
            Delete.self,
            Undelete.self,
            Export.self,
            Invoice.self,
            Project.self,
        ]
    )
}

PunchCardCLI.main()
