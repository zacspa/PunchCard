import Foundation
import Testing
@testable import PunchCardLib

@Suite("SyncService Tests")
struct SyncServiceTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-sync-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Empty config is returned when file is absent")
    func emptyConfig() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let sync = SyncService(directory: tempDir)
        let config = try sync.loadConfig()
        #expect(config.webhookURL == nil)
        #expect(!config.isConfigured)
    }

    @Test("saveConfig writes with 0600 permissions, no 0644 window")
    func saveConfigRestrictedPerms() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let sync = SyncService(directory: tempDir)
        try sync.saveConfig(SyncConfig(webhookURL: "https://example.com/hook", sharedSecret: "topsecret"))
        let path = tempDir.appendingPathComponent("sync.json").path
        let attrs = try FileManager.default.attributesOfItem(atPath: path)
        let perms = attrs[.posixPermissions] as? NSNumber
        #expect(perms?.int16Value == 0o600, "expected 0600, got \(String(describing: perms))")
    }

    @Test("validateHTTPSURL rejects http and non-URLs")
    func validateURL() throws {
        #expect(throws: SyncError.self) {
            _ = try SyncService.validateHTTPSURL("http://example.com/hook")
        }
        #expect(throws: SyncError.self) {
            _ = try SyncService.validateHTTPSURL("javascript:alert(1)")
        }
        #expect(throws: SyncError.self) {
            _ = try SyncService.validateHTTPSURL("not a url at all")
        }
        #expect(throws: SyncError.self) {
            _ = try SyncService.validateHTTPSURL(nil)
        }
        let ok = try SyncService.validateHTTPSURL("https://script.google.com/macros/s/abc/exec")
        #expect(ok.scheme == "https")
    }

    @Test("Retry queue persists IDs")
    func retryQueue() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let sync = SyncService(directory: tempDir)
        let id1 = UUID()
        let id2 = UUID()
        try sync.enqueueFailure(sessionID: id1)
        try sync.enqueueFailure(sessionID: id2)
        // Duplicate enqueue should be a no-op
        try sync.enqueueFailure(sessionID: id1)

        let queued = try sync.loadQueue()
        #expect(queued.count == 2)
        #expect(queued.contains(id1.uuidString))
        #expect(queued.contains(id2.uuidString))

        try sync.saveQueue([])
        #expect(try sync.loadQueue().isEmpty)
    }

    @Test("SyncConfig.isConfigured requires enabled + valid URL")
    func isConfiguredGates() {
        #expect(!SyncConfig().isConfigured)
        #expect(!SyncConfig(webhookURL: nil, enabled: true).isConfigured)
        #expect(!SyncConfig(webhookURL: "https://example.com", enabled: false).isConfigured)
        #expect(SyncConfig(webhookURL: "https://example.com", enabled: true).isConfigured)
    }
}

@Suite("Stop Clock Skew Tests")
struct StopClockSkewTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-skew-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("StopResult reports clockSkewClamped=false in the normal path")
    func normalStopNotClamped() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        _ = try store.startSession(project: "TestProject")
        let result = try store.stopSessionDetailed(summary: "Done", commits: [])
        #expect(!result.clockSkewClamped)
    }

    @Test("stopSession (legacy API) still returns the Session directly")
    func legacyStopReturnsSession() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let store = SessionStore(directory: tempDir)
        _ = try store.startSession(project: "TestProject")
        let session = try store.stopSession(summary: "Done", commits: [])
        #expect(session.project == "TestProject")
    }
}
