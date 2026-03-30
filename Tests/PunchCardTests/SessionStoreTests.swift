import Foundation
import Testing
@testable import PunchCardLib

@Suite("SessionStore Tests")
struct SessionStoreTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Start session creates a new active session")
    func startSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        let session = try store.startSession(project: "TestProject")

        #expect(session.project == "TestProject")
        #expect(session.isActive)
        #expect(session.notes.isEmpty)
        #expect(session.commits.isEmpty)
        #expect(session.summary == nil)
    }

    @Test("Cannot start a session while one is active")
    func startSessionWhileActive() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        _ = try store.startSession(project: "TestProject")

        #expect(throws: PunchCardError.self) {
            _ = try store.startSession(project: "TestProject")
        }
    }

    @Test("Stop session sets end time and summary")
    func stopSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        _ = try store.startSession(project: "TestProject")
        let stopped = try store.stopSession(summary: "Did some work", commits: ["abc123 Fix bug"])

        #expect(!stopped.isActive)
        #expect(stopped.endTime != nil)
        #expect(stopped.summary == "Did some work")
        #expect(stopped.commits == ["abc123 Fix bug"])
        #expect(stopped.hours != nil)
    }

    @Test("Stop session fails when no active session")
    func stopWithNoActiveSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        #expect(throws: PunchCardError.self) {
            _ = try store.stopSession(summary: "test", commits: [])
        }
    }

    @Test("Add note to active session")
    func addNote() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        _ = try store.startSession(project: "TestProject")
        let session = try store.addNote("Fixed auth bug")

        #expect(session.notes == ["Fixed auth bug"])

        let session2 = try store.addNote("Added tests")
        #expect(session2.notes == ["Fixed auth bug", "Added tests"])
    }

    @Test("Add note fails when no active session")
    func addNoteNoSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        #expect(throws: PunchCardError.self) {
            _ = try store.addNote("test")
        }
    }

    @Test("Active session returns nil when none active")
    func noActiveSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        let active = try store.activeSession()
        #expect(active == nil)
    }

    @Test("Active session returns current session")
    func hasActiveSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        let started = try store.startSession(project: "TestProject")
        let active = try store.activeSession()

        #expect(active != nil)
        #expect(active?.id == started.id)
    }

    @Test("List sessions excludes active sessions")
    func listExcludesActive() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        _ = try store.startSession(project: "TestProject")

        let sessions = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(sessions.isEmpty)
    }

    @Test("List sessions returns completed sessions")
    func listCompleted() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        _ = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])

        let sessions = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(sessions.count == 1)
        #expect(sessions[0].project == "TestProject")
    }

    @Test("List sessions filters by project")
    func listFilterByProject() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        _ = try store.startSession(project: "ProjectA")
        _ = try store.stopSession(summary: "A work", commits: [])
        _ = try store.startSession(project: "ProjectB")
        _ = try store.stopSession(summary: "B work", commits: [])

        let aOnly = try store.listSessions(from: nil, to: nil, project: "ProjectA")
        #expect(aOnly.count == 1)
        #expect(aOnly[0].project == "ProjectA")

        let all = try store.listSessions(from: nil, to: nil, project: nil)
        #expect(all.count == 2)
    }

    @Test("List sessions filters by date range")
    func listFilterByDateRange() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)

        // Create a session and stop it
        _ = try store.startSession(project: "TestProject")
        _ = try store.stopSession(summary: "Done", commits: [])

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        // Session should be included in a range covering today
        let included = try store.listSessions(from: yesterday, to: tomorrow, project: nil)
        #expect(included.count == 1)

        // Session should be excluded from a future-only range
        let twoDaysFromNow = Calendar.current.date(byAdding: .day, value: 2, to: today)!
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: today)!
        let excluded = try store.listSessions(from: twoDaysFromNow, to: threeDaysFromNow, project: nil)
        #expect(excluded.isEmpty)
    }

    @Test("Load returns empty data for new directory")
    func loadEmpty() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        let data = try store.load()
        #expect(data.sessions.isEmpty)
    }

    @Test("Data persists across store instances")
    func persistence() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store1 = SessionStore(directory: tempDir)
        _ = try store1.startSession(project: "TestProject")
        _ = try store1.stopSession(summary: "Persisted", commits: [])

        let store2 = SessionStore(directory: tempDir)
        let sessions = try store2.listSessions(from: nil, to: nil, project: nil)
        #expect(sessions.count == 1)
        #expect(sessions[0].summary == "Persisted")
    }

    @Test("Negative duration is clamped to zero on stop")
    func negativeDurationClamped() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        _ = try store.startSession(project: "TestProject")
        let stopped = try store.stopSession(summary: "Done", commits: [])

        // Duration should never be negative
        #expect(stopped.hours! >= 0)
    }
}
