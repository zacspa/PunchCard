import ArgumentParser
import Foundation

public struct Config: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage PunchCard configuration (e.g. Google Sheet sync).",
        subcommands: [Show.self, SetWebhook.self, SetSecret.self, Disable.self, Enable.self, QR.self],
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

    public struct QR: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "qr",
            abstract: "Print a QR code to pair a project with the mobile app.",
            discussion: """
            The mobile app keeps per-project webhook URLs and secrets. This
            command emits a QR code for one project at a time, using the CLI's
            current global webhook + secret as that project's sync target.

              punchcard config qr Acme

            Scan from the PunchCard mobile app (Settings → Scan project QR).
            Because the QR contains the secret, do not screenshot or share it
            publicly.
            """
        )

        @Argument(help: "Project to pair. Must be a registered project on the CLI.")
        var project: String?

        @Flag(name: .long, help: "Omit the shared secret from the QR. Enter it on the phone by hand.")
        var noSecret: Bool = false

        public init() {}

        public func run() throws {
            let sync = SyncService()
            let config = (try? sync.loadConfig()) ?? SyncConfig()
            guard let webhook = config.webhookURL, !webhook.isEmpty else {
                throw ValidationError("No webhook URL set. Run `punchcard config set-webhook <url>` first.")
            }

            let name = try resolveProjectName()
            let secret = noSecret ? nil : config.sharedSecret

            guard let uri = ConfigURI.encodeProject(
                name: name,
                webhookURL: webhook,
                sharedSecret: secret,
                enabled: true
            ) else {
                throw ValidationError("Could not encode project URI.")
            }
            let qr = try TerminalQR.render(uri)
            print(qr)
            print()
            print("Project: \(name)")
            print("Scan with PunchCard mobile → Settings → Scan project QR.")
            if secret != nil {
                print("Contains the shared secret — don't share or screenshot this QR.")
            } else if config.sharedSecret != nil {
                print("Secret omitted (--no-secret). Enter it on the phone by hand.")
            }
        }

        private func resolveProjectName() throws -> String {
            let registered = (try? ProjectStore().list()) ?? []
            if let arg = project?.trimmingCharacters(in: .whitespaces), !arg.isEmpty {
                if !registered.contains(where: { $0.caseInsensitiveCompare(arg) == .orderedSame }) {
                    let list = registered.isEmpty ? "(none registered)" : registered.joined(separator: ", ")
                    throw ValidationError("Project '\(arg)' is not registered. Known: \(list). Add it with `punchcard project add \(arg)`.")
                }
                // Match the registered capitalization so the phone/sheet agree.
                return registered.first { $0.caseInsensitiveCompare(arg) == .orderedSame } ?? arg
            }
            if registered.isEmpty {
                throw ValidationError("No projects registered. Run `punchcard project add <name>` first.")
            }
            throw ValidationError("""
                Specify a project. Registered projects:
                  \(registered.joined(separator: "\n  "))

                Example: punchcard config qr \(registered.first ?? "<name>")
                """)
        }
    }
}
