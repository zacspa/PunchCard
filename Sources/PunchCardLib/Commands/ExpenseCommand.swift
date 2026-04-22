import ArgumentParser
import Foundation

public struct ExpenseCmd: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "expense",
        abstract: "Manage expenses from the CLI.",
        subcommands: [Add.self]
    )

    public init() {}

    public struct Add: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Add an expense and sync it to the sheet.",
            discussion: """
            Posts directly to the configured sync webhook — the same endpoint
            the mobile app uses. Requires `punchcard config set-webhook` and
            a shared secret. If an image path is supplied, the file is
            base64-encoded and uploaded to the Drive folder the Apps Script
            manages (same flow as a mobile capture).
            """
        )

        @Option(name: .long, help: "Project name (must be registered).")
        var project: String

        @Option(name: .long, help: "Merchant / vendor name.")
        var merchant: String

        @Option(name: .long, help: "Amount in the expense's currency, e.g. 14.20.")
        var amount: Double

        @Option(name: .long, help: "Captured date (yyyy-MM-dd). Defaults to today.")
        var date: String?

        @Option(name: .long, help: "Captured time (HH:mm, 24-hour). Defaults to 12:00.")
        var time: String?

        @Option(name: .long, help: "Category (meals, travel, software, supplies, or custom).")
        var category: String?

        @Option(name: .long, help: "Free-form note.")
        var note: String?

        @Flag(name: .long, help: "Mark as NOT billable (default is billable).")
        var notBillable: Bool = false

        @Option(name: .long, help: "Path to a receipt image to attach.")
        var image: String?

        @Option(name: .long, help: "ISO currency code (default USD).")
        var currency: String = "USD"

        public init() {}

        public func run() throws {
            guard amount > 0 else {
                throw ValidationError("--amount must be positive.")
            }

            let projectStore = ProjectStore()
            guard try projectStore.validate(project) else {
                throw PunchCardError.invalidProject(project)
            }

            let capturedAt = try resolveDate()
            let amountCents = Int((amount * 100).rounded())
            let nowISO = DateFormatting.formatISO8601(Date())
            let id = UUID().uuidString.uppercased()

            var payload: [String: Any] = [
                "id": id,
                "project": project,
                "merchant": merchant,
                "amountCents": amountCents,
                "currency": currency,
                "capturedAt": DateFormatting.formatISO8601(capturedAt),
                "billable": !notBillable,
                "createdAt": nowISO,
                "updatedAt": nowISO,
                "deleted": false,
            ]
            if let category = category, !category.isEmpty {
                payload["category"] = category
            }
            if let note = note, !note.isEmpty {
                payload["note"] = note
            }

            if let imagePath = image {
                let url = URL(fileURLWithPath: (imagePath as NSString).expandingTildeInPath)
                let data = try Data(contentsOf: url)
                payload["receiptImageBase64"] = data.base64EncodedString()
                payload["receiptImageName"] = url.lastPathComponent
            }

            let sync = SyncService()
            _ = try sync.postExpense(payload)

            let billableLabel = notBillable ? "personal" : "billable"
            let amountText = String(format: "%.2f", amount)
            print("Expense added: \(merchant) — $\(amountText) (\(billableLabel), \(project))")
            if image != nil {
                print("  Receipt uploaded to Drive.")
            }
        }

        private func resolveDate() throws -> Date {
            let dateString = date ?? DateFormatting.formatDateOnly(Date())
            guard let day = DateFormatting.parseDate(dateString) else {
                throw ValidationError("Invalid --date: '\(dateString)'. Use yyyy-MM-dd.")
            }
            let timeString = time ?? "12:00"
            let parts = timeString.split(separator: ":").map(String.init)
            guard parts.count == 2,
                  let hours = Int(parts[0]), hours >= 0, hours < 24,
                  let minutes = Int(parts[1]), minutes >= 0, minutes < 60 else {
                throw ValidationError("Invalid --time: '\(timeString)'. Use HH:mm (24-hour).")
            }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .current
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = hours
            comps.minute = minutes
            comps.second = 0
            guard let combined = cal.date(from: comps) else {
                throw ValidationError("Couldn't combine --date and --time.")
            }
            return combined
        }
    }
}
