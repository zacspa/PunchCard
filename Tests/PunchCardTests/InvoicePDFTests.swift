import CoreGraphics
import Foundation
import PDFKit
import Testing
@testable import PunchCardLib

/// Extract all text from a PDF file using PDFKit
func extractPDFText(from url: URL) -> String {
    guard let document = PDFDocument(url: url) else { return "" }
    var text = ""
    for i in 0..<document.pageCount {
        if let page = document.page(at: i), let pageText = page.string {
            text += pageText
        }
    }
    return text
}

@Suite("InvoicePDFGenerator Tests")
struct InvoicePDFTests {
    let tempDir: URL

    init() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("punchcard-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    @Test("Generate a valid PDF file")
    func generatePDF() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-invoice.pdf")

        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Jane Doe",
            client: "Acme Corp",
            fromDate: DateFormatting.parseDate("2026-03-01")!,
            toDate: DateFormatting.parseDate("2026-03-31")!,
            hourlyRate: 150,
            lineItems: [
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-10")!, hours: 4.5, description: "Implemented authentication"),
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-15")!, hours: 6.0, description: "Built API endpoints"),
            ]
        )

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        // Verify file exists and is a valid PDF
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        let data = try Data(contentsOf: outputURL)
        let header = String(data: data.prefix(4), encoding: .ascii)
        #expect(header == "%PDF")
    }

    @Test("PDF contains invoice title and number")
    func pdfContainsTitleAndNumber() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-title.pdf")

        let invoice = InvoiceData(
            invoiceNumber: 42,
            name: "Jane Doe",
            client: "Acme Corp",
            fromDate: DateFormatting.parseDate("2026-03-01")!,
            toDate: DateFormatting.parseDate("2026-03-31")!,
            hourlyRate: 100,
            lineItems: [
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-10")!, hours: 4.0, description: "Work"),
            ]
        )

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        let text = extractPDFText(from: outputURL)
        #expect(text.contains("INVOICE"))
        #expect(text.contains("0042"))
    }

    @Test("PDF contains sender and client names")
    func pdfContainsNames() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-names.pdf")

        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Jane Smith",
            client: "MegaCorp Industries",
            fromDate: DateFormatting.parseDate("2026-03-01")!,
            toDate: DateFormatting.parseDate("2026-03-31")!,
            hourlyRate: 100,
            lineItems: [
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-10")!, hours: 4.0, description: "Work"),
            ]
        )

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        let text = extractPDFText(from: outputURL)
        #expect(text.contains("Jane Smith"))
        #expect(text.contains("MegaCorp Industries"))
    }

    @Test("PDF contains correct totals and rate")
    func pdfContainsTotals() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-totals.pdf")

        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Test User",
            client: "Test Client",
            fromDate: DateFormatting.parseDate("2026-03-01")!,
            toDate: DateFormatting.parseDate("2026-03-31")!,
            hourlyRate: 125,
            lineItems: [
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-10")!, hours: 4.0, description: "Day 1"),
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-12")!, hours: 6.5, description: "Day 2"),
            ]
        )

        // totalHours = 10.5, totalAmount = 10.5 * 125 = $1312.50
        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        let text = extractPDFText(from: outputURL)
        #expect(text.contains("10.50"))   // total hours
        #expect(text.contains("125.00"))  // rate
        #expect(text.contains("1312.50")) // total amount
    }

    @Test("PDF contains line item descriptions")
    func pdfContainsDescriptions() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-descriptions.pdf")

        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Test",
            client: "Client",
            fromDate: DateFormatting.parseDate("2026-03-01")!,
            toDate: DateFormatting.parseDate("2026-03-31")!,
            hourlyRate: 100,
            lineItems: [
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-10")!, hours: 3.0, description: "Implemented JWT authentication"),
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-15")!, hours: 5.0, description: "Built REST API endpoints"),
            ]
        )

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        let text = extractPDFText(from: outputURL)
        #expect(text.contains("JWT authentication"))
        #expect(text.contains("REST API endpoints"))
        #expect(text.contains("3.00"))  // hours for first item
        #expect(text.contains("5.00"))  // hours for second item
    }

    @Test("PDF contains date period")
    func pdfContainsPeriod() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-period.pdf")

        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Test",
            client: "Client",
            fromDate: DateFormatting.parseDate("2026-04-01")!,
            toDate: DateFormatting.parseDate("2026-04-15")!,
            hourlyRate: 100,
            lineItems: [
                InvoiceLineItem(date: DateFormatting.parseDate("2026-04-05")!, hours: 2.0, description: "Work"),
            ]
        )

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        let text = extractPDFText(from: outputURL)
        #expect(text.contains("2026-04-01"))
        #expect(text.contains("2026-04-15"))
    }

    @Test("PDF contains line item dates")
    func pdfContainsLineItemDates() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-dates.pdf")

        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Test",
            client: "Client",
            fromDate: DateFormatting.parseDate("2026-03-01")!,
            toDate: DateFormatting.parseDate("2026-03-31")!,
            hourlyRate: 100,
            lineItems: [
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-05")!, hours: 4.0, description: "Work A"),
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-20")!, hours: 3.0, description: "Work B"),
            ]
        )

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        let text = extractPDFText(from: outputURL)
        #expect(text.contains("2026-03-05"))
        #expect(text.contains("2026-03-20"))
    }

    @Test("Generate PDF with empty line items fails before reaching generator")
    func emptyInvoiceData() {
        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Jane Doe",
            client: "Acme Corp",
            fromDate: Date(),
            toDate: Date(),
            hourlyRate: 150,
            lineItems: []
        )
        #expect(invoice.totalHours == 0)
        #expect(invoice.totalAmount == 0)
    }

    @Test("Generate PDF with long description wraps text")
    func longDescription() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-long.pdf")

        let longDesc = "Implemented user authentication with JWT tokens, added login and signup endpoints with full validation, wrote comprehensive integration tests covering all edge cases, and documented the API"

        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Jane Doe",
            client: "Acme Corp",
            fromDate: DateFormatting.parseDate("2026-03-01")!,
            toDate: DateFormatting.parseDate("2026-03-31")!,
            hourlyRate: 100,
            lineItems: [
                InvoiceLineItem(date: DateFormatting.parseDate("2026-03-10")!, hours: 8.0, description: longDesc),
            ]
        )

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        let text = extractPDFText(from: outputURL)
        // Verify the full description made it into the PDF (even if wrapped)
        #expect(text.contains("JWT tokens"))
        #expect(text.contains("documented the API"))
    }

    @Test("Generate PDF with many line items spans multiple pages")
    func multiPageInvoice() throws {
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let outputURL = tempDir.appendingPathComponent("test-multipage.pdf")

        let baseDate = DateFormatting.parseDate("2026-03-01")!
        var lineItems: [InvoiceLineItem] = []
        for i in 0..<50 {
            let date = Calendar.current.date(byAdding: .day, value: i % 30, to: baseDate)!
            lineItems.append(InvoiceLineItem(
                date: date,
                hours: 4.0,
                description: "Work session \(i + 1): implemented feature and wrote tests"
            ))
        }

        let invoice = InvoiceData(
            invoiceNumber: 1,
            name: "Jane Doe",
            client: "Acme Corp",
            fromDate: DateFormatting.parseDate("2026-03-01")!,
            toDate: DateFormatting.parseDate("2026-04-30")!,
            hourlyRate: 125,
            lineItems: lineItems
        )

        let generator = InvoicePDFGenerator()
        try generator.generate(invoice: invoice, to: outputURL)

        // Verify multi-page
        let document = PDFDocument(url: outputURL)
        #expect(document != nil)
        #expect(document!.pageCount > 1)

        // Verify totals are correct: 50 * 4.0 = 200 hours, 200 * 125 = $25,000
        let text = extractPDFText(from: outputURL)
        #expect(text.contains("200.00"))
        #expect(text.contains("25000.00"))
    }
}
