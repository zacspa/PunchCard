import ArgumentParser
import Foundation

public struct Project: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Manage registered projects.",
        subcommands: [Add.self, Remove.self, ProjectList.self]
    )

    public init() {}

    public struct Add: ParsableCommand {
        public static let configuration = CommandConfiguration(
            abstract: "Register a new project name."
        )

        @Argument(help: "Project name to register.")
        var name: String

        public init() {}

        public func run() throws {
            let store = ProjectStore()
            if try store.add(name) {
                print("Project '\(name)' registered.")
            } else {
                print("Project '\(name)' already exists.")
            }
        }
    }

    public struct Remove: ParsableCommand {
        public static let configuration = CommandConfiguration(
            abstract: "Unregister a project name."
        )

        @Argument(help: "Project name to remove.")
        var name: String

        public init() {}

        public func run() throws {
            let store = ProjectStore()
            let sessionStore = SessionStore()
            if try store.hasSessionsForProject(name, sessionStore: sessionStore) {
                print("Warning: project '\(name)' has existing sessions. Removing the project will not delete session data, but you won't be able to start new sessions for it.")
            }
            if try store.remove(name) {
                print("Project '\(name)' removed.")
            } else {
                print("Project '\(name)' not found.")
            }
        }
    }

    public struct ProjectList: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all registered projects."
        )

        public init() {}

        public func run() throws {
            let store = ProjectStore()
            let projects = try store.list()
            if projects.isEmpty {
                print("No projects registered. Add one with `punchcard project add \"Name\"`.")
            } else {
                print("Registered projects:")
                for project in projects {
                    print("  - \(project)")
                }
            }
        }
    }
}
