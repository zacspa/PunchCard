import Foundation

public enum Paths {
    /// Global data directory: ~/.punchcard/
    public static var dataDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".punchcard")
    }

    public static var sessionsFile: URL {
        dataDir.appendingPathComponent("sessions.json")
    }

    public static var projectsFile: URL {
        dataDir.appendingPathComponent("projects.json")
    }

    public static var invoicesDir: URL {
        dataDir.appendingPathComponent("invoices")
    }

    public static var syncConfigFile: URL {
        dataDir.appendingPathComponent("sync.json")
    }

    /// Lock file for session read-modify-write operations
    public static var lockFile: URL {
        dataDir.appendingPathComponent(".lock")
    }

    public static func ensureDirectoryExists(_ url: URL) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}
