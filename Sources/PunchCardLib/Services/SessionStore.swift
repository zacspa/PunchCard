import Foundation

public struct SessionStore {
    private let sessionsFile: URL
    private let dataDir: URL
    private let lockFileURL: URL

    public init() {
        self.dataDir = Paths.dataDir
        self.sessionsFile = Paths.sessionsFile
        self.lockFileURL = Paths.lockFile
    }

    public init(directory: URL) {
        self.dataDir = directory
        self.sessionsFile = directory.appendingPathComponent("sessions.json")
        self.lockFileURL = directory.appendingPathComponent(".lock")
    }

    // MARK: - File Locking

    /// Execute a closure while holding an exclusive file lock.
    /// Uses POSIX flock() to prevent concurrent read-modify-write races
    /// between separate CLI invocations.
    private func withLock<T>(_ body: () throws -> T) throws -> T {
        try Paths.ensureDirectoryExists(dataDir)
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

    // MARK: - Read/Write (internal — callers should use the locked public methods)

    func load() throws -> SessionData {
        guard FileManager.default.fileExists(atPath: sessionsFile.path) else {
            return SessionData()
        }
        let data = try Data(contentsOf: sessionsFile)
        return try DateFormatting.makeDecoder().decode(SessionData.self, from: data)
    }

    func save(_ sessionData: SessionData) throws {
        try Paths.ensureDirectoryExists(dataDir)
        // Auto-backup before overwriting
        if FileManager.default.fileExists(atPath: sessionsFile.path) {
            let bakFile = dataDir.appendingPathComponent("sessions.json.bak")
            try? FileManager.default.removeItem(at: bakFile)
            try? FileManager.default.copyItem(at: sessionsFile, to: bakFile)
        }
        let data = try DateFormatting.makeEncoder().encode(sessionData)
        try data.write(to: sessionsFile, options: .atomic)
    }

    /// Locked read — safe for external callers
    public func loadSessions() throws -> SessionData {
        try withLock { try load() }
    }

    // MARK: - Session Operations

    public func activeSession() throws -> Session? {
        try withLock {
            let data = try load()
            return data.sessions.first(where: { $0.isActive && !$0.isDeleted })
        }
    }

    public func startSession(project: String, startTime: Date = Date()) throws -> Session {
        try withLock {
            var data = try load()
            if let active = data.sessions.first(where: { $0.isActive && !$0.isDeleted }) {
                throw PunchCardError.sessionAlreadyActive(
                    project: active.project,
                    since: DateFormatting.formatDisplay(active.startTime)
                )
            }
            // Reject future start times (allow tiny clock skew)
            if startTime.timeIntervalSinceNow > 60 {
                throw PunchCardError.invalidStartTime(
                    reason: "Start time \(DateFormatting.formatDisplay(startTime)) is in the future."
                )
            }
            // Reject overlap with the most recent completed session
            let lastEnd = data.sessions
                .filter { !$0.isDeleted }
                .compactMap { $0.endTime }
                .max()
            if let lastEnd = lastEnd, startTime < lastEnd {
                throw PunchCardError.invalidStartTime(
                    reason: "Start time \(DateFormatting.formatDisplay(startTime)) overlaps previous session (ended \(DateFormatting.formatDisplay(lastEnd))). Use `punchcard edit` to adjust the prior session first."
                )
            }
            let session = Session(project: project, startTime: startTime)
            data.sessions.append(session)
            try save(data)
            return session
        }
    }

    public func stopSession(summary: String, commits: [String]) throws -> Session {
        try withLock {
            var data = try load()
            guard let index = data.sessions.firstIndex(where: { $0.isActive && !$0.isDeleted }) else {
                throw PunchCardError.noActiveSession
            }
            data.sessions[index].endTime = Date()
            data.sessions[index].summary = summary
            data.sessions[index].commits = commits
            // Guard against negative durations (clock adjustments)
            if let end = data.sessions[index].endTime,
               end < data.sessions[index].startTime {
                data.sessions[index].endTime = data.sessions[index].startTime
            }
            try save(data)
            return data.sessions[index]
        }
    }

    public func addNote(_ note: String) throws -> Session {
        try withLock {
            var data = try load()
            guard let index = data.sessions.firstIndex(where: { $0.isActive && !$0.isDeleted }) else {
                throw PunchCardError.noActiveSession
            }
            data.sessions[index].notes.append(note)
            try save(data)
            return data.sessions[index]
        }
    }

    public func deleteSession(id: UUID) throws -> Session {
        try withLock {
            var data = try load()
            guard let index = data.sessions.firstIndex(where: { $0.id == id && !$0.isDeleted }) else {
                throw PunchCardError.sessionNotFound(id: id.uuidString)
            }
            // If deleting an active session, set endTime so it's not a zombie
            if data.sessions[index].endTime == nil {
                data.sessions[index].endTime = Date()
            }
            data.sessions[index].deleted = true
            data.sessions[index].deletedAt = Date()
            try save(data)
            return data.sessions[index]
        }
    }

    public func undeleteSession(id: UUID) throws -> Session {
        try withLock {
            var data = try load()
            guard let index = data.sessions.firstIndex(where: { $0.id == id && $0.isDeleted }) else {
                throw PunchCardError.sessionNotFound(id: id.uuidString)
            }
            data.sessions[index].deleted = nil
            data.sessions[index].deletedAt = nil
            try save(data)
            return data.sessions[index]
        }
    }

    public func exportCSV(from: Date?, to: Date?, project: String?, includeDeleted: Bool = false) throws -> String {
        try withLock {
            let data = try load()
            var lines = ["Date,Project,Hours,Summary,Notes,Commits,Session ID,Deleted"]
            for session in data.sessions {
                if session.isActive { continue }
                if !includeDeleted && session.isDeleted { continue }
                if let from = from, session.startTime < from { continue }
                if let to = to {
                    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: to) ?? to
                    if session.startTime >= endOfDay { continue }
                }
                if let project = project, session.project != project { continue }

                let date = DateFormatting.formatDateOnly(session.startTime)
                let hours = String(format: "%.2f", session.hours ?? 0)
                let summary = csvEscape(session.summary ?? "")
                let notes = csvEscape(session.notes.joined(separator: "; "))
                let commits = csvEscape(session.commits.joined(separator: "; "))
                let deleted = session.isDeleted ? "yes" : ""
                lines.append("\(date),\(csvEscape(session.project)),\(hours),\(summary),\(notes),\(commits),\(session.id.uuidString),\(deleted)")
            }
            return lines.joined(separator: "\n")
        }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    public func editSession(
        id: UUID,
        project: String? = nil,
        summary: String? = nil,
        endTime: Date? = nil
    ) throws -> Session {
        try withLock {
            var data = try load()
            guard let index = data.sessions.firstIndex(where: { $0.id == id && !$0.isDeleted }) else {
                throw PunchCardError.sessionNotFound(id: id.uuidString)
            }
            if let project = project {
                data.sessions[index].project = project
            }
            if let summary = summary {
                data.sessions[index].summary = summary
            }
            if let endTime = endTime {
                data.sessions[index].endTime = endTime
                // Clamp negative durations
                if endTime < data.sessions[index].startTime {
                    data.sessions[index].endTime = data.sessions[index].startTime
                }
            }
            try save(data)
            return data.sessions[index]
        }
    }

    /// Filter sessions by date range and project.
    /// Note: sessions are attributed to the date they **started**. A session that starts
    /// at 11pm and ends at 2am will be attributed entirely to the start date. Total hours
    /// are always correct within a billing period, but sessions near midnight boundaries
    /// may appear under the previous day.
    public func listSessions(from: Date?, to: Date?, project: String?) throws -> [Session] {
        try withLock {
            let data = try load()
            return data.sessions.filter { session in
                guard !session.isActive, !session.isDeleted else { return false }
                if let from = from, session.startTime < from { return false }
                if let to = to {
                    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: to) ?? to
                    if session.startTime >= endOfDay { return false }
                }
                if let project = project, session.project != project { return false }
                return true
            }
        }
    }
}

public enum PunchCardError: Error, CustomStringConvertible, Equatable {
    case sessionAlreadyActive(project: String, since: String)
    case noActiveSession
    case invalidProject(String)
    case noSessionsInRange
    case lockFailed
    case sessionNotFound(id: String)
    case invalidStartTime(reason: String)

    public var description: String {
        switch self {
        case .sessionAlreadyActive(let project, let since):
            return "A session is already active for '\(project)' (started \(since)). Stop it first with `punchcard stop`."
        case .noActiveSession:
            return "No active session. Start one with `punchcard start --project <name>`."
        case .invalidProject(let name):
            return "'\(name)' is not a registered project. Add it with `punchcard project add \"\(name)\"`."
        case .sessionNotFound(let id):
            return "No session found with ID '\(id)'. Use `punchcard list` to see session IDs."
        case .noSessionsInRange:
            return "No completed sessions found in the specified date range."
        case .lockFailed:
            return "Failed to acquire file lock on ~/.punchcard/.lock"
        case .invalidStartTime(let reason):
            return reason
        }
    }
}
