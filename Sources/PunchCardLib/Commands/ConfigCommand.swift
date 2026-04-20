import ArgumentParser
import Foundation

public struct Config: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage PunchCard configuration (e.g. Google Sheet sync).",
        subcommands: [Show.self, SetWebhook.self, SetSecret.self, Disable.self, Enable.self],
        defaultSubcommand: Show.self
    )

    public init() {}

    public struct Show: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "show",
            abstract: "Show current configuration."
        )

        @Flag(name: .long, help: "Print the webhook URL in full instead of redacting it.")
        var reveal: Bool = false

        public init() {}

        public func run() throws {
            let sync = SyncService()
            let config: SyncConfig
            do {
                config = try sync.loadConfig()
            } catch {
                throw ValidationError("Could not read ~/.punchcard/sync.json — \(error.localizedDescription). Delete it or fix the JSON to recover.")
            }
            print("Sheet sync:")
            print("  Enabled:    \(config.enabled ? "yes" : "no")")
            print("  Webhook:    \(displayWebhook(config.webhookURL))")
            print("  Secret:     \(config.sharedSecret == nil ? "(not set)" : "(set, \(config.sharedSecret!.count) chars)")")
            print("  Configured: \(config.isConfigured ? "yes" : "no")")
        }

        private func displayWebhook(_ url: String?) -> String {
            guard let url = url, !url.isEmpty else { return "(not set)" }
            if reveal { return url }
            // Show scheme + host + 6-char tail so misconfigurations are visible
            // without leaking the full capability.
            guard let parsed = URL(string: url),
                  let host = parsed.host else {
                return "(set, redacted)"
            }
            let tail = url.suffix(6)
            return "\(parsed.scheme ?? "?")://\(host)/…\(tail)  (use --reveal to show full URL)"
        }
    }

    public struct SetWebhook: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "set-webhook",
            abstract: "Set the Google Apps Script / HTTP webhook URL for sync.",
            discussion: "Provide the URL as the argument, or pass --stdin to read from standard input (avoids leaking it into shell history)."
        )

        @Argument(help: "The webhook URL. Must be https.")
        var url: String?

        @Flag(name: .long, help: "Read the webhook URL from stdin instead of the argument.")
        var stdin: Bool = false

        public init() {}

        public func run() throws {
            let resolved = try resolveURL()
            let parsed = try Self.validateHTTPSURL(resolved)
            let sync = SyncService()
            var config = (try? sync.loadConfig()) ?? SyncConfig()
            config.webhookURL = parsed.absoluteString
            config.enabled = true
            try sync.saveConfig(config)
            print("Webhook saved. Sync is enabled.")
        }

        private func resolveURL() throws -> String {
            if stdin {
                guard let line = SecretReader.read(prompt: "Webhook URL: "),
                      !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                    throw ValidationError("No URL received on stdin.")
                }
                return line.trimmingCharacters(in: .whitespaces)
            }
            if let url = url { return url }
            throw ValidationError("Pass a URL as the argument or use --stdin.")
        }

        static func validateHTTPSURL(_ string: String) throws -> URL {
            guard let url = URL(string: string) else {
                throw ValidationError("Not a valid URL: '\(string)'.")
            }
            guard let scheme = url.scheme?.lowercased(), scheme == "https" else {
                throw ValidationError("Webhook URL must use https (got '\(url.scheme ?? "none")'). The secret travels with the request — http is not acceptable.")
            }
            guard url.host != nil else {
                throw ValidationError("Webhook URL must include a host.")
            }
            return url
        }
    }

    public struct SetSecret: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "set-secret",
            abstract: "Set a shared secret sent as the X-PunchCard-Secret header.",
            discussion: "With no argument, reads the secret from the terminal with echo disabled (recommended — passing it on the command line leaks it into shell history)."
        )

        @Argument(help: "The shared secret. Omit to read from stdin with echo off. Pass an empty string to clear.")
        var secret: String?

        public init() {}

        public func run() throws {
            let resolved: String
            if let cli = secret {
                if !cli.isEmpty {
                    FileHandle.standardError.write(Data("Warning: passing the secret on the command line leaks it to shell history. Prefer `punchcard config set-secret` with no argument.\n".utf8))
                }
                resolved = cli
            } else {
                guard let line = SecretReader.read(prompt: "Shared secret (input hidden): ") else {
                    throw ValidationError("No secret received on stdin.")
                }
                resolved = line
            }

            let sync = SyncService()
            var config = (try? sync.loadConfig()) ?? SyncConfig()
            config.sharedSecret = resolved.isEmpty ? nil : resolved
            try sync.saveConfig(config)
            print(resolved.isEmpty ? "Shared secret cleared." : "Shared secret saved.")
        }
    }

    public struct Disable: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "disable",
            abstract: "Disable sheet sync without removing the webhook."
        )

        public init() {}

        public func run() throws {
            let sync = SyncService()
            var config = (try? sync.loadConfig()) ?? SyncConfig()
            config.enabled = false
            try sync.saveConfig(config)
            print("Sheet sync disabled.")
        }
    }

    public struct Enable: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "enable",
            abstract: "Re-enable sheet sync."
        )

        public init() {}

        public func run() throws {
            let sync = SyncService()
            var config = (try? sync.loadConfig()) ?? SyncConfig()
            config.enabled = true
            try sync.saveConfig(config)
            print("Sheet sync enabled.")
        }
    }
}
