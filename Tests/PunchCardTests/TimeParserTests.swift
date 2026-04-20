import Foundation
import Testing
@testable import PunchCardLib

@Suite("TimeParser Tests")
struct TimeParserTests {
    // A fixed "now" in local time so tests are deterministic regardless of
    // when they run.
    private func fixedNow() -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 18
        comps.hour = 14; comps.minute = 0
        return Calendar.current.date(from: comps)!
    }

    @Test("Parses HH:mm as today's time")
    func parseTimeOnly24h() throws {
        let now = fixedNow()
        let parsed = try #require(TimeParser.parseAt("09:15", now: now))
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(comps.year == 2026)
        #expect(comps.month == 4)
        #expect(comps.day == 18)
        #expect(comps.hour == 9)
        #expect(comps.minute == 15)
    }

    @Test("Parses 12:00pm as noon today")
    func parseNoon() throws {
        let now = fixedNow()
        let parsed = try #require(TimeParser.parseAt("12:00pm", now: now))
        let comps = Calendar.current.dateComponents([.hour, .minute], from: parsed)
        #expect(comps.hour == 12)
        #expect(comps.minute == 0)
    }

    @Test("Parses 9am / 9 AM / 9:00 AM variants")
    func parseAmVariants() throws {
        let now = fixedNow()
        for input in ["9am", "9 AM", "9:00 am", "9:00am"] {
            let parsed = try #require(TimeParser.parseAt(input, now: now), "failed on '\(input)'")
            let comps = Calendar.current.dateComponents([.hour, .minute], from: parsed)
            #expect(comps.hour == 9, "wrong hour for '\(input)'")
            #expect(comps.minute == 0, "wrong minute for '\(input)'")
        }
    }

    @Test("Time-only strings in the future roll back to yesterday")
    func rollbackFutureTime() throws {
        // now is 14:00 today; 11:30pm would be in the future today → should resolve to yesterday
        let now = fixedNow()
        let parsed = try #require(TimeParser.parseAt("11:30pm", now: now))
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(comps.day == 17)
        #expect(comps.hour == 23)
        #expect(comps.minute == 30)
    }

    @Test("Parses full ISO 8601")
    func parseISO() throws {
        let parsed = try #require(TimeParser.parseAt("2026-04-18T09:00:00Z"))
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        #expect(iso.string(from: parsed) == "2026-04-18T09:00:00Z")
    }

    @Test("Parses date + time in local zone")
    func parseDateTime() throws {
        let parsed = try #require(TimeParser.parseAt("2026-04-18 09:00"))
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: parsed)
        #expect(comps.year == 2026)
        #expect(comps.month == 4)
        #expect(comps.day == 18)
        #expect(comps.hour == 9)
        #expect(comps.minute == 0)
    }

    @Test("parseDuration handles hours and minutes")
    func parseDurations() {
        #expect(TimeParser.parseDuration("30m") == TimeInterval(30 * 60))
        #expect(TimeParser.parseDuration("1h") == TimeInterval(3600))
        #expect(TimeParser.parseDuration("1h30m") == TimeInterval(3600 + 30 * 60))
        #expect(TimeParser.parseDuration("2h15m") == TimeInterval(2 * 3600 + 15 * 60))
        #expect(TimeParser.parseDuration("90") == TimeInterval(90 * 60)) // bare integer = minutes
        #expect(TimeParser.parseDuration("  1H  ") == TimeInterval(3600)) // case + whitespace
    }

    @Test("parseDuration rejects nonsense")
    func parseDurationInvalid() {
        #expect(TimeParser.parseDuration("") == nil)
        #expect(TimeParser.parseDuration("later") == nil)
        #expect(TimeParser.parseDuration("1x") == nil)
    }

    @Test("parseAt rejects garbage")
    func parseAtInvalid() {
        #expect(TimeParser.parseAt("notatime") == nil)
        #expect(TimeParser.parseAt("") == nil)
    }
}
