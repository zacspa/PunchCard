import Foundation

public enum DateFormatting {
    /// ISO 8601 formatter — matches the encoding used by JSONEncoder/.iso8601
    /// (no fractional seconds, to stay consistent with Codable round-trips)
    private nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private nonisolated(unsafe) static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private nonisolated(unsafe) static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    private nonisolated(unsafe) static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    public static func parseDate(_ string: String) -> Date? {
        dateOnly.date(from: string)
    }

    public static func formatDateOnly(_ date: Date) -> String {
        dateOnly.string(from: date)
    }

    public static func formatDisplay(_ date: Date) -> String {
        display.string(from: date)
    }

    public static func formatTime(_ date: Date) -> String {
        timeOnly.string(from: date)
    }

    public static func formatISO8601(_ date: Date) -> String {
        iso8601.string(from: date)
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
