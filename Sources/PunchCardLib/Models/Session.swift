import Foundation

public struct Session: Codable, Identifiable, Sendable {
    public let id: UUID
    public var project: String
    public let startTime: Date
    public var endTime: Date?
    public var notes: [String]
    public var summary: String?
    public var commits: [String]
    public var deleted: Bool?
    public var deletedAt: Date?

    public var isActive: Bool { endTime == nil && !(deleted ?? false) }
    public var isDeleted: Bool { deleted ?? false }

    public var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return max(0, end.timeIntervalSince(startTime))
    }

    public var hours: Double? {
        guard let d = duration else { return nil }
        return d / 3600.0
    }

    public var formattedDuration: String {
        let elapsed: TimeInterval
        if let end = endTime {
            elapsed = max(0, end.timeIntervalSince(startTime))
        } else {
            elapsed = max(0, Date().timeIntervalSince(startTime))
        }
        let totalMinutes = Int(elapsed) / 60
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }

    public init(project: String, startTime: Date = Date()) {
        self.id = UUID()
        self.project = project
        self.startTime = startTime
        self.endTime = nil
        self.notes = []
        self.summary = nil
        self.commits = []
        self.deleted = nil
        self.deletedAt = nil
    }
}

public struct SessionData: Codable, Sendable {
    public var sessions: [Session]

    public init() {
        self.sessions = []
    }
}
