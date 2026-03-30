import Foundation

public struct ProjectStore {
    private let projectsFile: URL
    private let directory: URL
    private let lockFileURL: URL

    public init() {
        self.directory = Paths.dataDir
        self.projectsFile = Paths.projectsFile
        self.lockFileURL = Paths.dataDir.appendingPathComponent(".projects-lock")
    }

    public init(directory: URL) {
        self.directory = directory
        self.projectsFile = directory.appendingPathComponent("projects.json")
        self.lockFileURL = directory.appendingPathComponent(".projects-lock")
    }

    // MARK: - File Locking

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        try Paths.ensureDirectoryExists(directory)
        let fd = open(lockFileURL.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else {
            throw PunchCardError.lockFailed
        }
        defer { close(fd) }

        guard flock(fd, LOCK_EX) == 0 else {
            throw PunchCardError.lockFailed
        }
        defer { flock(fd, LOCK_UN) }

        return try body()
    }

    // MARK: - Read/Write (internal)

    func load() throws -> ProjectConfig {
        guard FileManager.default.fileExists(atPath: projectsFile.path) else {
            return ProjectConfig()
        }
        let data = try Data(contentsOf: projectsFile)
        return try JSONDecoder().decode(ProjectConfig.self, from: data)
    }

    func save(_ config: ProjectConfig) throws {
        try Paths.ensureDirectoryExists(directory)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: projectsFile, options: .atomic)
    }

    // MARK: - Public Operations (locked)

    public func add(_ name: String) throws -> Bool {
        try withLock {
            var config = try load()
            let result = config.add(name)
            if result {
                try save(config)
            }
            return result
        }
    }

    public func remove(_ name: String) throws -> Bool {
        try withLock {
            var config = try load()
            let result = config.remove(name)
            if result {
                try save(config)
            }
            return result
        }
    }

    public func list() throws -> [String] {
        try withLock {
            let config = try load()
            return config.projects
        }
    }

    public func validate(_ name: String) throws -> Bool {
        try withLock {
            let config = try load()
            return config.validate(name)
        }
    }

    /// Check if any sessions reference this project name (uses locked session read)
    public func hasSessionsForProject(_ name: String, sessionStore: SessionStore) throws -> Bool {
        let data = try sessionStore.loadSessions()
        return data.sessions.contains { $0.project == name && !$0.isDeleted }
    }
}
