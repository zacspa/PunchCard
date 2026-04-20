import Foundation

/// Parses user-supplied start times for `punchcard start --at` and `--ago`.
///
/// Supported `--at` forms (all resolved in the provided calendar / time zone):
///   - ISO 8601 with zone: `2026-04-18T09:15:00Z`, `2026-04-18T09:15:00-04:00`
///   - ISO 8601 without zone (treated as local): `2026-04-18T09:15:00`
///   - Date + time (local): `2026-04-18 09:15`, `2026-04-18 9:15am`
///   - Time only (today, local): `09:15`, `9:15`, `9am`, `12:00pm`
///
/// Supported `--ago`: `30m`, `1h`, `1h30m`, `90m`, `2h15m`, or a bare integer (minutes).
///
/// Time-only strings are rejected with a helpful error if the resulting time is
/// in the future (no silent rollback to "yesterday") and if the clock-time
/// does not exist on the given calendar day (spring-forward DST gap).
public enum TimeParser {
    public enum Error: Swift.Error, CustomStringConvertible, Equatable {
        case empty
        case malformed(String)
        case futureTimeOnly(String)
        case nonExistentDueToDST(String)

        public var description: String {
            switch self {
            case .empty:
                return "Time input is empty."
            case .malformed(let input):
                return "Could not parse time '\(input)'. Try \"09:15\", \"12:00pm\", \"2026-04-18 09:00\", or ISO 8601 with offset."
            case .futureTimeOnly(let input):
                return "Time '\(input)' resolves to later today. If you meant a prior day, pass a full date (e.g. \"2026-04-17 23:30\") or use --ago."
            case .nonExistentDueToDST(let input):
                return "Time '\(input)' does not exist on this calendar day (DST gap). Try a time 1 hour later or pass an explicit ISO 8601 timestamp."
            }
        }
    }

    /// Parse a user-supplied time. Throws a descriptive error on failure.
    public static func parseAt(
        _ input: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Date {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw Error.empty }

        // 1) ISO 8601 with zone
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: trimmed) { return d }

        // 2) ISO 8601 without zone — treat as local
        let localIsoFormats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm",
        ]
        for fmt in localIsoFormats {
            if let d = localDateFormatter(fmt, calendar: calendar).date(from: trimmed) { return d }
        }

        // 3) Date + time (local)
        let dateTimeFormats = [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd h:mma",
            "yyyy-MM-dd h:mm a",
            "yyyy-MM-dd ha",
            "yyyy-MM-dd h a",
        ]
        for fmt in dateTimeFormats {
            if let d = localDateFormatter(fmt, calendar: calendar).date(from: trimmed) { return d }
        }

        // 4) Time only (today)
        let timeFormats = [
            "HH:mm",
            "H:mm",
            "h:mma",
            "h:mm a",
            "ha",
            "h a",
            "h:mm",
        ]
        for fmt in timeFormats {
            let f = localDateFormatter(fmt, calendar: calendar)
            guard let parsed = f.date(from: trimmed) else { continue }
            let parts = calendar.dateComponents([.hour, .minute, .second], from: parsed)
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = parts.hour
            components.minute = parts.minute
            components.second = parts.second ?? 0
            guard let candidate = calendar.date(from: components) else {
                throw Error.nonExistentDueToDST(trimmed)
            }
            // DST round-trip check: ensure constructed time has the same hour/minute.
            let back = calendar.dateComponents([.hour, .minute], from: candidate)
            if back.hour != parts.hour || back.minute != parts.minute {
                throw Error.nonExistentDueToDST(trimmed)
            }
            // Reject future times rather than silently rolling back.
            if candidate > now.addingTimeInterval(60) {
                throw Error.futureTimeOnly(trimmed)
            }
            return candidate
        }

        throw Error.malformed(trimmed)
    }

    /// Parse a duration like `30m`, `1h`, `1h30m`, `90m`, `2h15m`, or a bare
    /// integer (minutes). Throws on malformed input.
    public static func parseDuration(_ input: String) throws -> TimeInterval {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { throw Error.empty }

        // Bare integer = minutes
        if let minutes = Int(trimmed), minutes >= 0 {
            return TimeInterval(minutes * 60)
        }

        let pattern = #"^(?:(\d+)h)?(?:(\d+)m)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw Error.malformed(trimmed)
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              match.range(at: 0).length > 0 else {
            throw Error.malformed(trimmed)
        }

        func groupValue(_ index: Int) -> Int {
            let r = match.range(at: index)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: trimmed),
                  let v = Int(trimmed[swiftRange]) else { return 0 }
            return v
        }

        let hours = groupValue(1)
        let minutes = groupValue(2)
        if hours == 0 && minutes == 0 { throw Error.malformed(trimmed) }
        return TimeInterval(hours * 3600 + minutes * 60)
    }

    private static func localDateFormatter(_ format: String, calendar: Calendar = .current) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }
}
