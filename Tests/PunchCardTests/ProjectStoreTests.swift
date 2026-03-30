import Foundation
import Testing
@testable import PunchCardLib

@Suite("ProjectStore Tests")
struct ProjectStoreTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Add a new project")
    func addProject() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        let added = try store.add("MyProject")
        #expect(added == true)

        let projects = try store.list()
        #expect(projects == ["MyProject"])
    }

    @Test("Adding duplicate project returns false")
    func addDuplicate() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        _ = try store.add("MyProject")
        let added = try store.add("MyProject")
        #expect(added == false)

        let projects = try store.list()
        #expect(projects.count == 1)
    }

    @Test("Remove an existing project")
    func removeProject() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        _ = try store.add("MyProject")
        let removed = try store.remove("MyProject")
        #expect(removed == true)

        let projects = try store.list()
        #expect(projects.isEmpty)
    }

    @Test("Remove non-existent project returns false")
    func removeNonExistent() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        let removed = try store.remove("Ghost")
        #expect(removed == false)
    }

    @Test("Validate returns true for registered project")
    func validateRegistered() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        _ = try store.add("MyProject")
        let valid = try store.validate("MyProject")
        #expect(valid == true)
    }

    @Test("Validate returns false for unregistered project")
    func validateUnregistered() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        let valid = try store.validate("Ghost")
        #expect(valid == false)
    }

    @Test("Projects are sorted alphabetically")
    func sortedProjects() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        _ = try store.add("Zebra")
        _ = try store.add("Alpha")
        _ = try store.add("Middle")

        let projects = try store.list()
        #expect(projects == ["Alpha", "Middle", "Zebra"])
    }

    @Test("Empty string is not added")
    func rejectEmpty() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        let added = try store.add("   ")
        #expect(added == false)

        let projects = try store.list()
        #expect(projects.isEmpty)
    }

    @Test("Whitespace is trimmed from project names")
    func trimWhitespace() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        _ = try store.add("  Padded  ")

        let projects = try store.list()
        #expect(projects == ["Padded"])
    }

    @Test("Validate trims whitespace to match add")
    func validateTrimsWhitespace() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        _ = try store.add("MyProject")
        let valid = try store.validate("  MyProject  ")
        #expect(valid == true)
    }

    @Test("Remove trims whitespace to match add")
    func removeTrimsWhitespace() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = ProjectStore(directory: tempDir)
        _ = try store.add("MyProject")
        let removed = try store.remove("  MyProject  ")
        #expect(removed == true)
        #expect(try store.list().isEmpty)
    }

    @Test("Data persists across store instances")
    func persistence() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store1 = ProjectStore(directory: tempDir)
        _ = try store1.add("Persisted")

        let store2 = ProjectStore(directory: tempDir)
        let projects = try store2.list()
        #expect(projects == ["Persisted"])
    }

    @Test("hasSessionsForProject detects existing sessions")
    func hasSessionsForProject() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let projectStore = ProjectStore(directory: tempDir)
        let sessionStore = SessionStore(directory: tempDir)

        _ = try projectStore.add("MyProject")
        _ = try sessionStore.startSession(project: "MyProject")
        _ = try sessionStore.stopSession(summary: "Done", commits: [])

        let has = try projectStore.hasSessionsForProject("MyProject", sessionStore: sessionStore)
        #expect(has == true)

        let hasNone = try projectStore.hasSessionsForProject("Other", sessionStore: sessionStore)
        #expect(hasNone == false)
    }
}
