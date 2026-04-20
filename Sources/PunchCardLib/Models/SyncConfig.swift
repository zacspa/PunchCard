import Foundation

public struct SyncConfig: Codable, Sendable {
    public var webhookURL: String?
    public var sharedSecret: String?
    public var enabled: Bool

    public init(webhookURL: String? = nil, sharedSecret: String? = nil, enabled: Bool = true) {
        self.webhookURL = webhookURL
        self.sharedSecret = sharedSecret
        self.enabled = enabled
    }

    public var isConfigured: Bool {
        guard enabled, let url = webhookURL, !url.isEmpty else { return false }
        return URL(string: url) != nil
    }
}
