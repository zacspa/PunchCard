import Foundation

public struct ProjectConfig: Codable, Sendable {
    public var projects: [String]

    public init() {
        self.projects = []
    }

    public mutating func add(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty else { return false }
        if projects.contains(normalized) { return false }
        projects.append(normalized)
        projects.sort()
        return true
    }

    public mutating func remove(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespaces)
        if let index = projects.firstIndex(of: normalized) {
            projects.remove(at: index)
            return true
        }
        return false
    }

    public func validate(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespaces)
        return projects.contains(normalized)
    }
}
