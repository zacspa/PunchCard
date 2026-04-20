import Foundation
import Testing
@testable import PunchCardLib

@Suite("TimeParser Tests")
struct TimeParserTests {
    // A deterministic calendar / time zone so tests don't depend on CI host TZ.
    private static let easternCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }()

    private func fixedNow(year: Int = 2026, month: Int = 4, day: Int = 18, hour: Int = 14, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        comps.timeZone = TimeParserTests.easternCalendar.timeZone
        return TimeParserTests.easternCalendar.date(from: comps)!
    }

    @Test("Parses HH:mm as today's time")
    func parseTimeOnly24h() throws {
        let now = fixedNow()
        let parsed = try TimeParser.parseAt("09:15", now: now, calendar: TimeParserTests.easternCalendar)
        let comps = TimeParserTests.easternCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(comps.year == 2026)
        #expect(comps.month == 4)
        #expect(comps.day == 18)
        #expect(comps.hour == 9)
        #expect(comps.minute == 15)
    }

    @Test("Parses 12:00pm as noon today")
    func parseNoon() throws {
        let now = fixedNow()
        let parsed = try TimeParser.parseAt("12:00pm", now: now, calendar: TimeParserTests.easternCalendar)
        let comps = TimeParserTests.easternCalendar.dateComponents([.hour, .minute], from: parsed)
        #expect(comps.hour == 12)
        #expect(comps.minute == 0)
    }

    @Test("Parses 9am / 9 AM / 9:00 AM variants")
    func parseAmVariants() throws {
        let now = fixedNow()
        for input in ["9am", "9 AM", "9:00 am", "9:00am"] {
            let parsed = try TimeParser.parseAt(input, now: now, calendar: TimeParserTests.easternCalendar)
            let comps = TimeParserTests.easternCalendar.dateComponents([.hour, .minute], from: parsed)
            #expect(comps.hour == 9, "wrong hour for '\(input)'")
            #expect(comps.minute == 0, "wrong minute for '\(input)'")
        }
    }

    @Test("Future time-only strings are rejected (no silent rollback)")
    func rejectsFutureTime() {
        let now = fixedNow()
        #expect(throws: TimeParser.Error.self) {
            _ = try TimeParser.parseAt("11:30pm", now: now, calendar: TimeParserTests.easternCalendar)
        }
    }

    @Test("DST spring-forward: 2:30am on 2026-03-08 does not exist in America/New_York")
    func dstSpringForwardRejected() {
        // 2026-03-08 is the US spring-forward date; wall clock jumps from 02:00 to 03:00.
        // We use a 'now' that is on 2026-03-08 at 15:00 so "02:30" is today's time but invalid.
        let now = fixedNow(year: 2026, month: 3, day: 8, hour: 15, minute: 0)
        #expect(throws: TimeParser.Error.self) {
            _ = try TimeParser.parseAt("02:30", now: now, calendar: TimeParserTests.easternCalendar)
        }
    }

    @Test("Parses full ISO 8601 with zone")
    func parseISO() throws {
        let parsed = try TimeParser.parseAt("2026-04-18T09:00:00Z")
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        #expect(iso.string(from: parsed) == "2026-04-18T09:00:00Z")
    }

    @Test("Parses ISO 8601 without zone (local)")
    func parseISONoZone() throws {
        let parsed = try TimeParser.parseAt(
            "2026-04-18T09:00:00",
            calendar: TimeParserTests.easternCalendar
        )
        let comps = TimeParserTests.easternCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(comps.year == 2026)
        #expect(comps.day == 18)
        #expect(comps.hour == 9)
    }

    @Test("Parses date + time in local zone")
    func parseDateTime() throws {
        let parsed = try TimeParser.parseAt(
            "2026-04-18 09:00",
            calendar: TimeParserTests.easternCalendar
        )
        let comps = TimeParserTests.easternCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(comps.year == 2026)
        #expect(comps.month == 4)
        #expect(comps.day == 18)
        #expect(comps.hour == 9)
        #expect(comps.minute == 0)
    }

    @Test("parseDuration handles hours and minutes")
    func parseDurations() throws {
        #expect(try TimeParser.parseDuration("30m") == TimeInterval(30 * 60))
        #expect(try TimeParser.parseDuration("1h") == TimeInterval(3600))
        #expect(try TimeParser.parseDuration("1h30m") == TimeInterval(3600 + 30 * 60))
        #expect(try TimeParser.parseDuration("2h15m") == TimeInterval(2 * 3600 + 15 * 60))
        #expect(try TimeParser.parseDuration("90") == TimeInterval(90 * 60)) // bare integer = minutes
        #expect(try TimeParser.parseDuration("  1H  ") == TimeInterval(3600)) // case + whitespace
    }

    @Test("parseDuration rejects nonsense")
    func parseDurationInvalid() {
        #expect(throws: TimeParser.Error.self) { _ = try TimeParser.parseDuration("") }
        #expect(throws: TimeParser.Error.self) { _ = try TimeParser.parseDuration("later") }
        #expect(throws: TimeParser.Error.self) { _ = try TimeParser.parseDuration("1x") }
    }

    @Test("parseAt rejects garbage")
    func parseAtInvalid() {
        #expect(throws: TimeParser.Error.self) { _ = try TimeParser.parseAt("notatime") }
        #expect(throws: TimeParser.Error.self) { _ = try TimeParser.parseAt("") }
    }
}
