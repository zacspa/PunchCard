import Foundation
import Testing
@testable import PunchCardLib

@Suite("DateFormatting Tests")
struct DateFormattingTests {
    @Test("Parse valid date string")
    func parseValid() {
        let date = DateFormatting.parseDate("2026-03-15")
        #expect(date != nil)
    }

    @Test("Parse invalid date string returns nil")
    func parseInvalid() {
        #expect(DateFormatting.parseDate("not-a-date") == nil)
        #expect(DateFormatting.parseDate("March 15") == nil)
        #expect(DateFormatting.parseDate("") == nil)
    }

    @Test("Format date only produces yyyy-MM-dd")
    func formatDateOnly() {
        let date = DateFormatting.parseDate("2026-03-15")!
        let formatted = DateFormatting.formatDateOnly(date)
        #expect(formatted == "2026-03-15")
    }

    @Test("Date round-trips through parse and format")
    func roundTrip() {
        let original = "2026-12-25"
        let date = DateFormatting.parseDate(original)!
        let formatted = DateFormatting.formatDateOnly(date)
        #expect(formatted == original)
    }

    @Test("JSON encoder uses ISO 8601 dates")
    func encoderUsesISO8601() throws {
        let encoder = DateFormatting.makeEncoder()
        let decoder = DateFormatting.makeDecoder()
        let session = Session(project: "Test")

        let data = try encoder.encode(session)
        let decoded = try decoder.decode(Session.self, from: data)

        // Dates should survive round-trip within 1 second
        let diff = abs(session.startTime.timeIntervalSince(decoded.startTime))
        #expect(diff < 1.0)
    }
}
