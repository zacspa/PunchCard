import Foundation

public struct InvoiceData: Sendable {
    public let invoiceNumber: Int
    public let name: String
    public let client: String
    public let fromDate: Date
    public let toDate: Date
    public let hourlyRate: Double
    public let lineItems: [InvoiceLineItem]
    public let expenses: [InvoiceExpenseItem]
    public let logoPath: String?
    public let email: String?
    public let clientAddress: String?
    public let terms: String?
    public let paymentMethod: String?

    public var totalHours: Double {
        lineItems.reduce(0) { $0 + $1.hours }
    }

    public var servicesAmount: Double {
        totalHours * hourlyRate
    }

    public var expensesAmount: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    public var totalAmount: Double {
        servicesAmount + expensesAmount
    }

    public init(invoiceNumber: Int, name: String, client: String, fromDate: Date, toDate: Date, hourlyRate: Double, lineItems: [InvoiceLineItem], expenses: [InvoiceExpenseItem] = [], logoPath: String? = nil, email: String? = nil, clientAddress: String? = nil, terms: String? = nil, paymentMethod: String? = nil) {
        self.invoiceNumber = invoiceNumber
        self.name = name
        self.client = client
        self.fromDate = fromDate
        self.toDate = toDate
        self.hourlyRate = hourlyRate
        self.lineItems = lineItems
        self.expenses = expenses
        self.logoPath = logoPath
        self.email = email
        self.clientAddress = clientAddress
        self.terms = terms
        self.paymentMethod = paymentMethod
    }
}

public struct InvoiceExpenseItem: Sendable {
    public let date: Date
    public let merchant: String
    public let note: String?
    public let amountCents: Int
    public let currency: String

    public var amount: Double {
        Double(amountCents) / 100.0
    }

    public var description: String {
        guard let note = note, !note.isEmpty else { return merchant }
        return "\(merchant) — \(note)"
    }

    public init(date: Date, merchant: String, note: String?, amountCents: Int, currency: String) {
        self.date = date
        self.merchant = merchant
        self.note = note
        self.amountCents = amountCents
        self.currency = currency
    }
}

/// Manages a simple auto-incrementing invoice counter in ~/.punchcard/invoice-counter.txt
public enum InvoiceCounter {
    public static func next(directory: URL? = nil) throws -> Int {
        let dir = directory ?? Paths.dataDir
        try Paths.ensureDirectoryExists(dir)

        let lockFile = dir.appendingPathComponent(".invoice-lock")
        let fd = open(lockFile.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { throw PunchCardError.lockFailed }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw PunchCardError.lockFailed }
        defer { flock(fd, LOCK_UN) }

        let counterFile = dir.appendingPathComponent("invoice-counter.txt")
        var current = 0
        if let data = try? String(contentsOf: counterFile, encoding: .utf8),
           let value = Int(data.trimmingCharacters(in: .whitespacesAndNewlines)) {
            current = value
        }
        let next = current + 1
        try String(next).write(to: counterFile, atomically: true, encoding: .utf8)
        return next
    }
}

public struct InvoiceLineItem: Sendable {
    public let date: Date
    public let hours: Double
    public let description: String

    public init(date: Date, hours: Double, description: String) {
        self.date = date
        self.hours = hours
        self.description = description
    }
}
