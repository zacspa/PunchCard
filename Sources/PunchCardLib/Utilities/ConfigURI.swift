import Foundation

/// Encodes a project's sync configuration as a deep-link URI consumable by
/// the PunchCard mobile app: `punchcard://project?name=…&url=…&secret=…&enabled=1`.
///
/// Keep this in lockstep with `mobile/lib/config/uri.ts`. The mobile app's
/// Settings → Scan QR flow parses exactly this format.
public enum ConfigURI {
    public static let scheme = "punchcard"
    public static let host = "project"

    /// Encode a per-project URI. `webhookURL` and `sharedSecret` are typically
    /// the CLI's current global sync config, which the phone assigns to the
    /// named project on scan.
    public static func encodeProject(
        name: String,
        webhookURL: String,
        sharedSecret: String? = nil,
        enabled: Bool = true
    ) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !webhookURL.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        var items: [URLQueryItem] = [
            URLQueryItem(name: "name", value: trimmedName),
            URLQueryItem(name: "url", value: webhookURL),
            URLQueryItem(name: "enabled", value: enabled ? "1" : "0"),
        ]
        if let secret = sharedSecret, !secret.isEmpty {
            items.append(URLQueryItem(name: "secret", value: secret))
        }
        components.queryItems = items
        return components.url?.absoluteString
    }
}
