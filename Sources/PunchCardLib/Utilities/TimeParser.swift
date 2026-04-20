import Foundation

/// Parses user-supplied start/end times from the CLI in flexible formats.
///
/// Supported `--at` forms (all resolved against `now` in the caller's locale):
///   - ISO 8601: `2026-04-18T09:15:00Z`, `2026-04-18T09:15:00-04:00`
///   - Date + time: `2026-04-18 09:15`, `2026-04-18 9:15am`
///   - Time only (today): `09:15`, `9:15`, `9am`, `12:00pm`, `3 PM`
///
/// Supported `--ago` forms: `30m`, `1h`, `1h30m`, `90m`, `2h15m`
public enum TimeParser {
    /// Parse a time string into an absolute `Date`. Time-only strings resolve
    /// to today's date in the current calendar. If the resulting time is in the
    /// future (within 12 hours), it's rolled back to yesterday so that
    /// `--at 11:30pm` at 1am means "last night" not "23 hours from now".
    public static func parseAt(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // ISO 8601 with timezone
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: trimmed) { return d }

        // Date + time (local)
        let dateTimeFormats = [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd h:mma",
            "yyyy-MM-dd h:mm a",
            "yyyy-MM-dd ha",
            "yyyy-MM-dd h a",
        ]
        for fmt in dateTimeFormats {
            if let d = localDateFormatter(fmt).date(from: trimmed) { return d }
        }

        // Time-only: parse against today, roll back if unreasonably in the future.
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
            let f = localDateFormatter(fmt)
            guard let parsed = f.date(from: trimmed) else { continue }
            let parts = calendar.dateComponents([.hour, .minute, .second], from: parsed)
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = parts.hour
            components.minute = parts.minute
            components.second = parts.second ?? 0
            guard var candidate = calendar.date(from: components) else { continue }
            // If the time-of-day is later today than now, assume the user meant
            // yesterday — e.g. punching in at 00:10 with --at 11:30pm.
            if candidate > now.addingTimeInterval(60) {
                candidate = calendar.date(byAdding: .day, value: -1, to: candidate) ?? candidate
            }
            return candidate
        }

        return nil
    }

    /// Parse a duration like `30m`, `1h`, `1h30m`, `90m`, `2h15m` into a
    /// `TimeInterval` of seconds. Returns `nil` for malformed input.
    public static func parseDuration(_ input: String) -> TimeInterval? {
        let trimmed = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }

        // Bare integer = minutes
        if let minutes = Int(trimmed), minutes >= 0 {
            return TimeInterval(minutes * 60)
        }

        let pattern = #"^(?:(\d+)h)?(?:(\d+)m)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, range: range),
              match.range(at: 0).length > 0 else { return nil }

        func groupValue(_ index: Int) -> Int {
            let r = match.range(at: index)
            guard r.location != NSNotFound, let swiftRange = Range(r, in: trimmed),
                  let v = Int(trimmed[swiftRange]) else { return 0 }
            return v
        }

        let hours = groupValue(1)
        let minutes = groupValue(2)
        if hours == 0 && minutes == 0 { return nil }
        return TimeInterval(hours * 3600 + minutes * 60)
    }

    private static func localDateFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }
}
