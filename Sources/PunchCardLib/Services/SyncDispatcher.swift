import Foundation

/// Best-effort sync trigger used by write commands (stop/edit/delete/undelete).
/// On config / network / response failure, prints a single-line warning to
/// stderr and enqueues the session ID for later flushing via `punchcard sync`.
/// Never throws: sync is optional and must not block local persistence.
public enum SyncDispatcher {
    public enum Outcome {
        case skipped        // --no-sync or sync not configured
        case synced
        case failed         // warning was printed; session enqueued for retry
    }

    @discardableResult
    public static func pushBestEffort(_ session: Session, action: String = "upsert", noSync: Bool = false) -> Outcome {
        if noSync { return .skipped }
        let sync = SyncService()
        let config: SyncConfig
        do {
            config = try sync.loadConfig()
        } catch {
            FileHandle.standardError.write(Data("Warning: sync config is unreadable (\(error.localizedDescription)) — run `punchcard config show` to recover.\n".utf8))
            return .failed
        }
        guard config.isConfigured else { return .skipped }

        do {
            try sync.push(session, action: action)
            return .synced
        } catch {
            FileHandle.standardError.write(Data("Warning: sheet sync failed — \(error). Queued for retry via `punchcard sync --flush-queue`.\n".utf8))
            try? sync.enqueueFailure(sessionID: session.id)
            return .failed
        }
    }

    /// Emit a one-line confirmation on stdout when sync actually ran.
    public static func announce(_ outcome: Outcome) {
        if outcome == .synced {
            print("Synced to sheet.")
        }
    }
}
