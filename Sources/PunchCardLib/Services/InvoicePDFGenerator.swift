import AppKit
import CoreGraphics
import CoreText
import Foundation

struct InvoicePDFGenerator {
    // Page dimensions (US Letter)
    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let margin: CGFloat = 50
    private let lineHeight: CGFloat = 18

    // Column positions
    private var contentWidth: CGFloat { pageWidth - 2 * margin }
    private let dateColWidth: CGFloat = 80
    private let hoursColWidth: CGFloat = 60

    func generate(invoice: InvoiceData, to url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw InvoiceError.cannotCreatePDF
        }

        var yPosition: CGFloat = pageHeight - margin

        // Pre-load logo image for watermark on every page
        var logoImage: CGImage?
        if let logoPath = invoice.logoPath,
           let logoData = try? Data(contentsOf: URL(fileURLWithPath: logoPath)) as CFData,
           let dataProvider = CGDataProvider(data: logoData) {
            logoImage = CGImage(pngDataProviderSource: dataProvider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        }

        func drawWatermark() {
            guard let logoImage = logoImage else { return }
            let watermarkSize: CGFloat = 400
            let aspectRatio = CGFloat(logoImage.width) / CGFloat(logoImage.height)
            let watermarkWidth = aspectRatio >= 1 ? watermarkSize : watermarkSize * aspectRatio
            let watermarkHeight = aspectRatio >= 1 ? watermarkSize / aspectRatio : watermarkSize
            let watermarkX = (pageWidth - watermarkWidth) / 2
            let watermarkY = (pageHeight - watermarkHeight) / 2
            let watermarkRect = CGRect(x: watermarkX, y: watermarkY, width: watermarkWidth, height: watermarkHeight)
            context.saveGState()
            context.setAlpha(0.15)
            context.draw(logoImage, in: watermarkRect)
            context.restoreGState()
        }

        func startNewPage() {
            if yPosition < pageHeight - margin {
                context.endPDFPage()
            }
            context.beginPDFPage(nil)
            drawWatermark()
            yPosition = pageHeight - margin
        }

        // --- Page 1 ---
        startNewPage()

        // Title and invoice number
        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 28, nil)
        drawText("INVOICE", at: CGPoint(x: margin, y: yPosition), font: titleFont, color: .black, context: context)
        let invoiceNumFont = CTFontCreateWithName("Helvetica" as CFString, 12, nil)
        let invoiceNumStr = "#\(String(format: "%04d", invoice.invoiceNumber))"
        drawText(invoiceNumStr, at: CGPoint(x: pageWidth - margin - 50, y: yPosition), font: invoiceNumFont, color: CGColor(gray: 0.4, alpha: 1.0), context: context)
        yPosition -= 50

        // Sender & client info
        let labelFont = CTFontCreateWithName("Helvetica" as CFString, 11, nil)
        let valueFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 11, nil)
        let grayColor = CGColor(gray: 0.4, alpha: 1.0)

        drawText("From:", at: CGPoint(x: margin, y: yPosition), font: labelFont, color: grayColor, context: context)
        drawText(invoice.name, at: CGPoint(x: margin + 50, y: yPosition), font: valueFont, color: .black, context: context)
        yPosition -= lineHeight

        if let email = invoice.email {
            drawText("Email:", at: CGPoint(x: margin, y: yPosition), font: labelFont, color: grayColor, context: context)
            drawText(email, at: CGPoint(x: margin + 50, y: yPosition), font: valueFont, color: .black, context: context)
            yPosition -= lineHeight
        }

        drawText("To:", at: CGPoint(x: margin, y: yPosition), font: labelFont, color: grayColor, context: context)
        drawText(invoice.client, at: CGPoint(x: margin + 50, y: yPosition), font: valueFont, color: .black, context: context)
        yPosition -= lineHeight

        if let clientAddress = invoice.clientAddress {
            drawText("Address:", at: CGPoint(x: margin, y: yPosition), font: labelFont, color: grayColor, context: context)
            drawText(clientAddress, at: CGPoint(x: margin + 50, y: yPosition), font: valueFont, color: .black, context: context)
            yPosition -= lineHeight
        }

        let periodStr = "\(DateFormatting.formatDateOnly(invoice.fromDate)) to \(DateFormatting.formatDateOnly(invoice.toDate))"
        drawText("Period:", at: CGPoint(x: margin, y: yPosition), font: labelFont, color: grayColor, context: context)
        drawText(periodStr, at: CGPoint(x: margin + 50, y: yPosition), font: valueFont, color: .black, context: context)
        yPosition -= lineHeight

        let dateStr = DateFormatting.formatDateOnly(Date())
        drawText("Date:", at: CGPoint(x: margin, y: yPosition), font: labelFont, color: grayColor, context: context)
        drawText(dateStr, at: CGPoint(x: margin + 50, y: yPosition), font: valueFont, color: .black, context: context)
        yPosition -= lineHeight

        if let terms = invoice.terms {
            drawText("Terms:", at: CGPoint(x: margin, y: yPosition), font: labelFont, color: grayColor, context: context)
            drawText(terms, at: CGPoint(x: margin + 50, y: yPosition), font: valueFont, color: .black, context: context)
            yPosition -= lineHeight
        }

        yPosition -= 17

        // Table header drawing
        let colHeaderFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 10, nil)
        let descColX = margin + dateColWidth + hoursColWidth
        var inTableBody = false

        func drawTableHeader() {
            drawHLine(y: yPosition, from: margin, to: pageWidth - margin, color: .black, width: 1.0, context: context)
            yPosition -= 16
            drawText("Date", at: CGPoint(x: margin, y: yPosition), font: colHeaderFont, color: .black, context: context)
            drawText("Hours", at: CGPoint(x: margin + dateColWidth, y: yPosition), font: colHeaderFont, color: .black, context: context)
            drawText("Description", at: CGPoint(x: descColX, y: yPosition), font: colHeaderFont, color: .black, context: context)
            yPosition -= 16
            drawHLine(y: yPosition, from: margin, to: pageWidth - margin, color: CGColor(gray: 0.6, alpha: 1.0), width: 0.5, context: context)
            yPosition -= 5
        }

        func checkPageBreakWithHeader(needed: CGFloat) {
            if yPosition < margin + needed {
                startNewPage()
                if inTableBody {
                    drawTableHeader()
                }
            }
        }

        let rowFont = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let monoFont = CTFontCreateWithName("Menlo" as CFString, 9, nil)
        let rowPadding: CGFloat = 6

        if !invoice.lineItems.isEmpty {
            drawTableHeader()
            inTableBody = true
        }

        for (index, item) in invoice.lineItems.enumerated() {
            let dateText = DateFormatting.formatDateOnly(item.date)
            let hoursText = String(format: "%.2f", item.hours)
            let descMaxWidth = contentWidth - dateColWidth - hoursColWidth

            // Measure wrapped description height
            let descLines = wrapText(item.description, maxWidth: descMaxWidth, font: rowFont)
            let descTextHeight = CGFloat(descLines.count) * lineHeight
            let rowHeight = max(lineHeight, descTextHeight) + rowPadding * 2

            checkPageBreakWithHeader(needed: rowHeight)

            // Alternating row shading
            if index % 2 == 0 {
                let shadingRect = CGRect(x: margin - 5, y: yPosition - rowHeight + rowPadding, width: contentWidth + 10, height: rowHeight)
                context.setFillColor(CGColor(gray: 0.95, alpha: 0.6))
                context.fill(shadingRect)
            }

            // All columns vertically centered in the row
            // Single-line items (date, hours) centered at midpoint
            let midY = yPosition - rowHeight / 2 + 3
            drawText(dateText, at: CGPoint(x: margin, y: midY), font: rowFont, color: .black, context: context)
            drawText(hoursText, at: CGPoint(x: margin + dateColWidth, y: midY), font: monoFont, color: .black, context: context)

            // Multi-line description: center the block vertically
            let descBlockHeight = CGFloat(descLines.count) * lineHeight
            var descY = midY + (descBlockHeight - lineHeight) / 2
            for line in descLines {
                drawText(line, at: CGPoint(x: descColX, y: descY), font: rowFont, color: .black, context: context)
                descY -= lineHeight
            }

            yPosition -= rowHeight
        }

        // Footer totals
        inTableBody = false
        let paymentSpace: CGFloat = invoice.paymentMethod != nil ? 80 : 0
        checkPageBreakWithHeader(needed: 80 + paymentSpace)

        let totalFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 12, nil)
        let valueNumFont = CTFontCreateWithName("Menlo" as CFString, 11, nil)
        let rightCol: CGFloat = pageWidth - margin - 150
        let rightEdge = pageWidth - margin

        if !invoice.lineItems.isEmpty {
            yPosition -= 10
            drawHLine(y: yPosition, from: margin, to: pageWidth - margin, color: .black, width: 1.0, context: context)
            yPosition -= 22

            drawText("Total Hours:", at: CGPoint(x: rightCol, y: yPosition), font: totalFont, color: .black, context: context)
            drawTextRightAligned(String(format: "%.2f", invoice.totalHours), rightEdge: rightEdge, y: yPosition, font: valueNumFont, color: .black, context: context)
            yPosition -= 20

            drawText("Rate:", at: CGPoint(x: rightCol, y: yPosition), font: totalFont, color: .black, context: context)
            drawTextRightAligned(String(format: "$%.2f/hr", invoice.hourlyRate), rightEdge: rightEdge, y: yPosition, font: valueNumFont, color: .black, context: context)
            yPosition -= 20
        }

        if !invoice.expenses.isEmpty {
            if !invoice.lineItems.isEmpty {
                drawText("Services:", at: CGPoint(x: rightCol, y: yPosition), font: totalFont, color: .black, context: context)
                drawTextRightAligned(String(format: "$%.2f", invoice.servicesAmount), rightEdge: rightEdge, y: yPosition, font: valueNumFont, color: .black, context: context)
                yPosition -= 30
            }

            // Expenses table — reuses the date/amount column layout as services.
            checkPageBreakWithHeader(needed: 80)

            let sectionHeaderFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 12, nil)
            drawText("Billable Expenses", at: CGPoint(x: margin, y: yPosition), font: sectionHeaderFont, color: .black, context: context)
            yPosition -= 18
            drawHLine(y: yPosition, from: margin, to: pageWidth - margin, color: .black, width: 1.0, context: context)
            yPosition -= 16
            let amountColWidth: CGFloat = 90
            let expDescColX = margin + dateColWidth
            let expDescMaxWidth = contentWidth - dateColWidth - amountColWidth
            let amountColRight = pageWidth - margin
            drawText("Date", at: CGPoint(x: margin, y: yPosition), font: colHeaderFont, color: .black, context: context)
            drawText("Description", at: CGPoint(x: expDescColX, y: yPosition), font: colHeaderFont, color: .black, context: context)
            drawTextRightAligned("Amount", rightEdge: amountColRight, y: yPosition, font: colHeaderFont, color: .black, context: context)
            yPosition -= 16
            drawHLine(y: yPosition, from: margin, to: pageWidth - margin, color: CGColor(gray: 0.6, alpha: 1.0), width: 0.5, context: context)
            yPosition -= 5

            for (idx, exp) in invoice.expenses.enumerated() {
                let dateText = DateFormatting.formatDateOnly(exp.date)
                let descLines = wrapText(exp.description, maxWidth: expDescMaxWidth, font: rowFont)
                let descTextHeight = CGFloat(descLines.count) * lineHeight
                let rowHeight = max(lineHeight, descTextHeight) + rowPadding * 2

                if yPosition < margin + rowHeight {
                    startNewPage()
                }

                if idx % 2 == 0 {
                    let shadingRect = CGRect(x: margin - 5, y: yPosition - rowHeight + rowPadding, width: contentWidth + 10, height: rowHeight)
                    context.setFillColor(CGColor(gray: 0.95, alpha: 0.6))
                    context.fill(shadingRect)
                }

                let midY = yPosition - rowHeight / 2 + 3
                drawText(dateText, at: CGPoint(x: margin, y: midY), font: rowFont, color: .black, context: context)
                let descBlockHeight = CGFloat(descLines.count) * lineHeight
                var descY = midY + (descBlockHeight - lineHeight) / 2
                for line in descLines {
                    drawText(line, at: CGPoint(x: expDescColX, y: descY), font: rowFont, color: .black, context: context)
                    descY -= lineHeight
                }
                let amountText = String(format: "$%.2f", exp.amount)
                drawTextRightAligned(amountText, rightEdge: amountColRight, y: midY, font: monoFont, color: .black, context: context)
                yPosition -= rowHeight
            }

            yPosition -= 6
            drawHLine(y: yPosition, from: rightCol, to: rightEdge, color: CGColor(gray: 0.6, alpha: 1.0), width: 0.5, context: context)
            yPosition -= 18
            drawText("Expenses:", at: CGPoint(x: rightCol, y: yPosition), font: totalFont, color: .black, context: context)
            drawTextRightAligned(String(format: "$%.2f", invoice.expensesAmount), rightEdge: rightEdge, y: yPosition, font: valueNumFont, color: .black, context: context)
            yPosition -= 18
        }

        drawHLine(y: yPosition, from: rightCol, to: rightEdge, color: .black, width: 0.5, context: context)
        yPosition -= 20

        let grandTotalFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 14, nil)
        drawText("Total:", at: CGPoint(x: rightCol, y: yPosition), font: grandTotalFont, color: .black, context: context)
        drawTextRightAligned(String(format: "$%.2f", invoice.totalAmount), rightEdge: rightEdge, y: yPosition, font: grandTotalFont, color: .black, context: context)

        if let paymentMethod = invoice.paymentMethod {
            yPosition -= 40
            checkPageBreakWithHeader(needed: 40)
            drawHLine(y: yPosition, from: margin, to: pageWidth - margin, color: CGColor(gray: 0.6, alpha: 1.0), width: 0.5, context: context)
            yPosition -= 20
            let paymentHeaderFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 11, nil)
            drawText("Payment Instructions", at: CGPoint(x: margin, y: yPosition), font: paymentHeaderFont, color: .black, context: context)
            yPosition -= lineHeight
            drawText(paymentMethod, at: CGPoint(x: margin, y: yPosition), font: labelFont, color: .black, context: context)
        }

        context.endPDFPage()
        context.closePDF()
    }

    // MARK: - Drawing Helpers (Core Text)

    private func drawText(_ text: String, at point: CGPoint, font: CTFont, color: CGColor, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()
        context.textPosition = point
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func drawTextRightAligned(_ text: String, rightEdge: CGFloat, y: CGFloat, font: CTFont, color: CGColor, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)

        context.saveGState()
        context.textPosition = CGPoint(x: rightEdge - CGFloat(textWidth), y: y)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func drawHLine(y: CGFloat, from x1: CGFloat, to x2: CGFloat, color: CGColor, width: CGFloat, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.move(to: CGPoint(x: x1, y: y))
        context.addLine(to: CGPoint(x: x2, y: y))
        context.strokePath()
        context.restoreGState()
    }

    private func wrapText(_ text: String, maxWidth: CGFloat, font: CTFont) -> [String] {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        // Handle embedded newlines first, then word-wrap each paragraph
        let paragraphs = text.components(separatedBy: .newlines)
        var allLines: [String] = []
        for paragraph in paragraphs {
            allLines.append(contentsOf: wrapParagraph(paragraph, maxWidth: maxWidth, attrs: attrs))
        }
        return allLines.isEmpty ? [""] : allLines
    }

    private func wrapParagraph(_ text: String, maxWidth: CGFloat, attrs: [NSAttributedString.Key: Any]) -> [String] {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var lines: [String] = []
        var currentLine = ""

        for word in words {
            let candidate = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            let size = (candidate as NSString).size(withAttributes: attrs)
            if size.width <= maxWidth {
                currentLine = candidate
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                currentLine = word
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        return lines.isEmpty ? [""] : lines
    }
}

enum InvoiceError: Error, CustomStringConvertible {
    case cannotCreatePDF

    var description: String {
        switch self {
        case .cannotCreatePDF:
            return "Failed to create PDF file. Check that the output directory exists and is writable."
        }
    }
}
