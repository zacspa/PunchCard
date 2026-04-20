import ArgumentParser
import Foundation

public struct Invoice: ParsableCommand {
    public static let configuration = CommandConfiguration(
        abstract: "Generate a PDF invoice for a date range."
    )

    @Option(name: .long, help: "Start date (yyyy-MM-dd).")
    var from: String

    @Option(name: .long, help: "End date (yyyy-MM-dd).")
    var to: String

    @Option(name: .long, help: "Hourly rate.")
    var rate: Double

    @Option(name: .long, help: "Your name (invoice sender).")
    var name: String

    @Option(name: .long, help: "Client/employer name.")
    var client: String

    @Option(name: .long, help: "Filter by project name.")
    var project: String?

    @Option(name: .long, help: "Your email address.")
    var email: String?

    @Option(name: .long, help: "Client address or billing contact.")
    var clientAddress: String?

    @Option(name: .long, help: "Payment terms (e.g. \"Net 30\", \"Due upon receipt\").")
    var terms: String?

    @Option(name: .long, help: "Payment method/instructions (e.g. \"CashApp $handle\").")
    var paymentMethod: String?

    @Option(name: .long, help: "Output file path (defaults to .punchcard/invoices/).")
    var output: String?

    @Option(name: .long, help: "Path to a logo image to display at the top of the invoice.")
    var logo: String?

    public init() {}

    public func run() throws {
        guard let fromDate = DateFormatting.parseDate(from) else {
            throw ValidationError("Invalid --from date. Use yyyy-MM-dd format.")
        }
        guard let toDate = DateFormatting.parseDate(to) else {
            throw ValidationError("Invalid --to date. Use yyyy-MM-dd format.")
        }
        guard fromDate <= toDate else {
            throw ValidationError("--from date must be before or equal to --to date.")
        }
        guard rate > 0 else {
            throw ValidationError("--rate must be a positive number.")
        }

        // Validate project name if provided
        if let project = project {
            let projectStore = ProjectStore()
            guard try projectStore.validate(project) else {
                throw PunchCardError.invalidProject(project)
            }
        }

        let store = SessionStore()
        let sessions = try store.listSessions(from: fromDate, to: toDate, project: project)

        guard !sessions.isEmpty else {
            throw PunchCardError.noSessionsInRange
        }

        let lineItems = sessions.map { session in
            // Combine summary with in-session notes for a complete description
            var desc = session.summary ?? "Work session"
            if !session.notes.isEmpty {
                desc += ". Notes: " + session.notes.joined(separator: "; ")
            }
            return InvoiceLineItem(
                date: session.startTime,
                hours: session.hours ?? 0,
                description: desc
            )
        }

        let invoiceNumber = try InvoiceCounter.next()
        let invoiceData = InvoiceData(
            invoiceNumber: invoiceNumber,
            name: name,
            client: client,
            fromDate: fromDate,
            toDate: toDate,
            hourlyRate: rate,
            lineItems: lineItems,
            logoPath: logo,
            email: email,
            clientAddress: clientAddress,
            terms: terms,
            paymentMethod: paymentMethod
        )

        let outputURL: URL
        if let output = output {
            outputURL = URL(fileURLWithPath: output)
        } else {
            try Paths.ensureDirectoryExists(Paths.invoicesDir)
            let filename = "invoice-\(String(format: "%04d", invoiceNumber))-\(DateFormatting.formatDateOnly(fromDate))-to-\(DateFormatting.formatDateOnly(toDate)).pdf"
            outputURL = Paths.invoicesDir.appendingPathComponent(filename)
        }

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoiceData, to: outputURL)

        print("Invoice generated: \(outputURL.path)")
        print("  Period: \(DateFormatting.formatDateOnly(fromDate)) to \(DateFormatting.formatDateOnly(toDate))")
        print("  Sessions: \(sessions.count)")
        print("  Total hours: \(String(format: "%.2f", invoiceData.totalHours))")
        print("  Rate: $\(String(format: "%.2f", rate))/hr")
        print("  Total: $\(String(format: "%.2f", invoiceData.totalAmount))")
    }
}
