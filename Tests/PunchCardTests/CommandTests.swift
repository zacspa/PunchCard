import Foundation
import Testing
@testable import PunchCardLib

@Suite("Command Integration Tests")
struct CommandTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Full session lifecycle: start, log, stop, list")
    func fullLifecycle() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let sessionStore = SessionStore(directory: tempDir)
        let projectStore = ProjectStore(directory: tempDir)

        _ = try projectStore.add("TestProject")
        let started = try sessionStore.startSession(project: "TestProject")
        #expect(started.isActive)

        _ = try sessionStore.addNote("Fixed login bug")
        _ = try sessionStore.addNote("Added unit tests")

        let stopped = try sessionStore.stopSession(
            summary: "Fixed auth bug and added tests",
            commits: ["abc123 Fix login", "def456 Add tests"]
        )
        #expect(!stopped.isActive)
        #expect(stopped.summary == "Fixed auth bug and added tests")
        #expect(stopped.commits.count == 2)
        #expect(stopped.notes.count == 2)

        let sessions = try sessionStore.listSessions(from: nil, to: nil, project: nil)
        #expect(sessions.count == 1)
    }

    @Test("Start rejects unregistered project")
    func rejectUnregisteredProject() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let projectStore = ProjectStore(directory: tempDir)
        let valid = try projectStore.validate("UnknownProject")
        #expect(valid == false)
    }

    @Test("Multiple sessions for same project")
    func multipleSessions() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        _ = try store.startSession(project: "ProjectA")
        _ = try store.stopSession(summary: "Session 1", commits: [])
        _ = try store.startSession(project: "ProjectA")
        _ = try store.stopSession(summary: "Session 2", commits: [])
        _ = try store.startSession(project: "ProjectA")
        _ = try store.stopSession(summary: "Session 3", commits: [])

        let sessions = try store.listSessions(from: nil, to: nil, project: "ProjectA")
        #expect(sessions.count == 3)
    }

    @Test("Session data is centralized across projects")
    func centralizedData() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        _ = try store.startSession(project: "ProjectA")
        _ = try store.stopSession(summary: "A work", commits: [])
        _ = try store.startSession(project: "ProjectB")
        _ = try store.stopSession(summary: "B work", commits: [])

        let all = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(all.count == 2)

        let aOnly = try store.listSessions(from: nil, to: nil, project: "ProjectA")
        #expect(aOnly.count == 1)
        #expect(aOnly[0].summary == "A work")
    }
}

@Suite("Edit and Delete Tests")
struct EditDeleteTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Delete a session by ID")
    func deleteSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])

        let deleted = try store.deleteSession(id: session.id)
        #expect(deleted.id == session.id)

        let remaining = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(remaining.isEmpty)
    }

    @Test("Deleted session is soft-deleted and persisted for backup")
    func softDelete() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])
        _ = try store.deleteSession(id: session.id)

        // Not visible in normal queries
        let listed = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(listed.isEmpty)

        // But still in the raw data
        let raw = try store.load()
        #expect(raw.sessions.count == 1)
        #expect(raw.sessions[0].isDeleted)
        #expect(raw.sessions[0].deletedAt != nil)
    }

    @Test("Cannot edit a deleted session")
    func cannotEditDeleted() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])
        _ = try store.deleteSession(id: session.id)

        #expect(throws: PunchCardError.self) {
            _ = try store.editSession(id: session.id, summary: "new")
        }
    }

    @Test("Delete non-existent session throws error")
    func deleteNonExistent() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        #expect(throws: PunchCardError.self) {
            _ = try store.deleteSession(id: UUID())
        }
    }

    @Test("Edit session summary")
    func editSummary() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Wrong summary", commits: [])

        let edited = try store.editSession(id: session.id, summary: "Correct summary")
        #expect(edited.summary == "Correct summary")

        // Persisted
        let sessions = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(sessions[0].summary == "Correct summary")
    }

    @Test("Edit session project")
    func editProject() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "WrongProject")
        _ = try store.stopSession(summary: "Done", commits: [])

        let edited = try store.editSession(id: session.id, project: "CorrectProject")
        #expect(edited.project == "CorrectProject")
    }

    @Test("Edit session end time")
    func editEndTime() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])

        let newEnd = session.startTime.addingTimeInterval(7200) // 2 hours after start
        let edited = try store.editSession(id: session.id, endTime: newEnd)
        #expect(abs(edited.hours! - 2.0) < 0.01)
    }

    @Test("Edit with negative end time clamps to zero duration")
    func editNegativeEndTime() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])

        let beforeStart = session.startTime.addingTimeInterval(-3600)
        let edited = try store.editSession(id: session.id, endTime: beforeStart)
        #expect(edited.endTime == edited.startTime)
        #expect(edited.hours == 0)
    }

    @Test("Edit non-existent session throws error")
    func editNonExistent() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        #expect(throws: PunchCardError.self) {
            _ = try store.editSession(id: UUID(), summary: "test")
        }
    }

    @Test("Delete preserves other sessions")
    func deletePreservesOthers() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let s1 = try store.startSession(project: "A")
        _ = try store.stopSession(summary: "First", commits: [])
        _ = try store.startSession(project: "B")
        _ = try store.stopSession(summary: "Second", commits: [])

        _ = try store.deleteSession(id: s1.id)

        let remaining = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(remaining.count == 1)
        #expect(remaining[0].summary == "Second")
    }
}

@Suite("InvoiceCounter Tests")
struct InvoiceCounterTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Counter starts at 1")
    func startsAtOne() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let value = try InvoiceCounter.next(directory: tempDir)
        #expect(value == 1)
    }

    @Test("Counter increments sequentially")
    func incrementsSequentially() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let v1 = try InvoiceCounter.next(directory: tempDir)
        let v2 = try InvoiceCounter.next(directory: tempDir)
        let v3 = try InvoiceCounter.next(directory: tempDir)
        #expect(v1 == 1)
        #expect(v2 == 2)
        #expect(v3 == 3)
    }

    @Test("Counter persists across calls")
    func persists() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        _ = try InvoiceCounter.next(directory: tempDir)
        _ = try InvoiceCounter.next(directory: tempDir)

        // Read the file directly
        let counterFile = tempDir.appendingPathComponent("invoice-counter.txt")
        let contents = try String(contentsOf: counterFile, encoding: .utf8)
        #expect(contents.trimmingCharacters(in: .whitespacesAndNewlines) == "2")
    }

    @Test("Counter recovers from corrupted file")
    func recoversFromCorruption() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Write garbage to the counter file
        let counterFile = tempDir.appendingPathComponent("invoice-counter.txt")
        try "not_a_number".write(to: counterFile, atomically: true, encoding: .utf8)

        // Should reset to 1
        let value = try InvoiceCounter.next(directory: tempDir)
        #expect(value == 1)
    }
}

@Suite("StopCommand File Input Tests")
struct StopCommandFileTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Summary file with special characters is read correctly")
    func summaryFileSpecialChars() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        _ = try store.startSession(project: "Test")

        // Write a summary with special chars to a file
        let summaryFile = tempDir.appendingPathComponent("summary.txt")
        let specialSummary = """
        Implemented "JWT auth" with $ENV variables, fixed the `login` endpoint, \
        and added tests for edge-cases (100% coverage).
        """
        try specialSummary.write(to: summaryFile, atomically: true, encoding: .utf8)

        // Read it back the way StopCommand would
        let contents = try String(contentsOfFile: summaryFile.path, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let session = try store.stopSession(summary: contents, commits: [])
        #expect(session.summary!.contains("\"JWT auth\""))
        #expect(session.summary!.contains("$ENV"))
        #expect(session.summary!.contains("`login`"))
    }

    @Test("Commits file with multiple lines is parsed correctly")
    func commitsFileMultiLine() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let commitsFile = tempDir.appendingPathComponent("commits.txt")
        let commitLines = """
        abc1234 Fix login bug
        def5678 Add signup validation
        ghi9012 Write integration tests
        """
        try commitLines.write(to: commitsFile, atomically: true, encoding: .utf8)

        let contents = try String(contentsOfFile: commitsFile.path, encoding: .utf8)
        let commitList = contents
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        #expect(commitList.count == 3)
        #expect(commitList[0] == "abc1234 Fix login bug")
        #expect(commitList[2] == "ghi9012 Write integration tests")
    }
}

@Suite("Undelete Tests")
struct UndeleteTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Undelete restores a soft-deleted session")
    func undeleteSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])
        _ = try store.deleteSession(id: session.id)

        // Gone from list
        #expect(try store.listSessions(from: nil, to: nil, project: nil).isEmpty)

        // Restore it
        let restored = try store.undeleteSession(id: session.id)
        #expect(!restored.isDeleted)
        #expect(restored.summary == "Done")

        // Back in list
        let sessions = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(sessions.count == 1)
        #expect(sessions[0].id == session.id)
    }

    @Test("Undelete non-deleted session throws error")
    func undeleteNonDeleted() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])

        #expect(throws: PunchCardError.self) {
            _ = try store.undeleteSession(id: session.id)
        }
    }

    @Test("Undelete non-existent session throws error")
    func undeleteNonExistent() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        #expect(throws: PunchCardError.self) {
            _ = try store.undeleteSession(id: UUID())
        }
    }
}

@Suite("Export Tests")
struct ExportTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Export CSV contains header and session data")
    func exportCSV() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        _ = try store.startSession(project: "ProjectA")
        _ = try store.stopSession(summary: "Built feature X", commits: ["abc123 Fix"])

        let csv = try store.exportCSV(from: nil, to: nil, project: nil)
        let lines = csv.components(separatedBy: "\n")

        #expect(lines.count == 2) // header + 1 session
        #expect(lines[0] == "Date,Project,Hours,Summary,Notes,Commits,Session ID,Deleted")
        #expect(lines[1].contains("ProjectA"))
        #expect(lines[1].contains("Built feature X"))
        #expect(lines[1].contains("abc123 Fix"))
    }

    @Test("Export CSV filters by project")
    func exportFilterByProject() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        _ = try store.startSession(project: "A")
        _ = try store.stopSession(summary: "A work", commits: [])
        _ = try store.startSession(project: "B")
        _ = try store.stopSession(summary: "B work", commits: [])

        let csv = try store.exportCSV(from: nil, to: nil, project: "A")
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[1].contains(",A,"))
    }

    @Test("Export CSV excludes deleted by default")
    func exportExcludesDeleted() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let s = try store.startSession(project: "A")
        _ = try store.stopSession(summary: "Deleted", commits: [])
        _ = try store.deleteSession(id: s.id)
        _ = try store.startSession(project: "B")
        _ = try store.stopSession(summary: "Kept", commits: [])

        let csv = try store.exportCSV(from: nil, to: nil, project: nil)
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 2) // header + 1 non-deleted
        #expect(lines[1].contains("Kept"))
    }

    @Test("Export CSV includes deleted when flag is set")
    func exportIncludesDeleted() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let s = try store.startSession(project: "A")
        _ = try store.stopSession(summary: "Deleted", commits: [])
        _ = try store.deleteSession(id: s.id)
        _ = try store.startSession(project: "B")
        _ = try store.stopSession(summary: "Kept", commits: [])

        let csv = try store.exportCSV(from: nil, to: nil, project: nil, includeDeleted: true)
        let lines = csv.components(separatedBy: "\n")
        #expect(lines.count == 3) // header + 2 sessions
    }

    @Test("Export CSV escapes commas in summary")
    func exportEscapesCommas() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        _ = try store.startSession(project: "Test")
        _ = try store.stopSession(summary: "Fixed login, signup, and logout", commits: [])

        let csv = try store.exportCSV(from: nil, to: nil, project: nil)
        #expect(csv.contains("\"Fixed login, signup, and logout\""))
    }
}

@Suite("Backup Tests")
struct BackupTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Save creates a .bak file")
    func backupOnSave() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        // First save — no .bak yet (no prior file to back up)
        _ = try store.startSession(project: "Test")
        let bakFile = tempDir.appendingPathComponent("sessions.json.bak")
        // .bak exists after second write (stop triggers a save after sessions.json already exists)
        _ = try store.stopSession(summary: "Done", commits: [])

        #expect(FileManager.default.fileExists(atPath: bakFile.path))
    }

    @Test("Backup contains previous state")
    func backupContainsPreviousState() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        _ = try store.startSession(project: "First")
        _ = try store.stopSession(summary: "First done", commits: [])
        // At this point sessions.json has 1 completed session

        _ = try store.startSession(project: "Second")
        // Now sessions.json.bak should have the state before "Second" was added

        let bakFile = tempDir.appendingPathComponent("sessions.json.bak")
        let bakData = try Data(contentsOf: bakFile)
        let bakSessions = try DateFormatting.makeDecoder().decode(SessionData.self, from: bakData)
        #expect(bakSessions.sessions.count == 1)
        #expect(bakSessions.sessions[0].summary == "First done")
    }

    @Test("Deleting an active session sets endTime")
    func deleteActiveSessionSetsEndTime() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        let session = try store.startSession(project: "Test")
        #expect(session.isActive)

        _ = try store.deleteSession(id: session.id)

        let raw = try store.load()
        let deleted = raw.sessions[0]
        #expect(deleted.isDeleted)
        #expect(deleted.endTime != nil) // no zombie — endTime was set
    }
}
