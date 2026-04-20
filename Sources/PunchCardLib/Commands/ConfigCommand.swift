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

        public init() {}

        public func run() throws {
            let sync = SyncService()
            let config = try sync.loadConfig()
            print("Sheet sync:")
            print("  Enabled:    \(config.enabled ? "yes" : "no")")
            print("  Webhook:    \(config.webhookURL ?? "(not set)")")
            print("  Secret:     \(config.sharedSecret == nil ? "(not set)" : "(set)")")
            print("  Configured: \(config.isConfigured ? "yes" : "no")")
        }
    }

    public struct SetWebhook: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "set-webhook",
            abstract: "Set the Google Apps Script / HTTP webhook URL for sync."
        )

        @Argument(help: "The webhook URL (e.g. a Google Apps Script deployment URL).")
        var url: String

        public init() {}

        public func run() throws {
            guard URL(string: url) != nil else {
                throw ValidationError("Not a valid URL: '\(url)'.")
            }
            let sync = SyncService()
            var config = try sync.loadConfig()
            config.webhookURL = url
            config.enabled = true
            try sync.saveConfig(config)
            print("Webhook saved. Sync is enabled.")
        }
    }

    public struct SetSecret: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "set-secret",
            abstract: "Set a shared secret sent as X-PunchCard-Secret and body field."
        )

        @Argument(help: "The shared secret. Pass an empty string to clear.")
        var secret: String

        public init() {}

        public func run() throws {
            let sync = SyncService()
            var config = try sync.loadConfig()
            config.sharedSecret = secret.isEmpty ? nil : secret
            try sync.saveConfig(config)
            print(secret.isEmpty ? "Shared secret cleared." : "Shared secret saved.")
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
            var config = try sync.loadConfig()
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
            var config = try sync.loadConfig()
            config.enabled = true
            try sync.saveConfig(config)
            print("Sheet sync enabled.")
        }
    }
}
