import Foundation

/// All date math and formatting pinned to the studio's timezone (America/Toronto),
/// regardless of the device's timezone.
nonisolated enum StudioTime {
    static let timeZone: TimeZone = TimeZone(identifier: "America/Toronto") ?? .current
    static let locale: Locale = Locale(identifier: "en_US")

    static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        cal.locale = locale
        return cal
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    /// - Parameter weekStartDay: 0 = Sunday … 6 = Saturday.
    static func startOfWeek(containing date: Date, weekStartDay: Int) -> Date {
        let day = startOfDay(date)
        let weekday = calendar.component(.weekday, from: day) - 1
        let offset = (weekday - weekStartDay + 14) % 7
        return addDays(-offset, to: day)
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    // MARK: Parsing

    nonisolated(unsafe) private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    nonisolated(unsafe) private static let fallbackParsers: [DateFormatter] = [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
        "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX",
        "yyyy-MM-dd HH:mm:ssXXXXX",
        "yyyy-MM-dd HH:mm:ssX",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd"
    ].map { pattern in
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = pattern
        return f
    }

    static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let d = isoFractional.date(from: string) { return d }
        if let d = isoPlain.date(from: string) { return d }
        for parser in fallbackParsers {
            if let d = parser.date(from: string) { return d }
        }
        return nil
    }

    static func isoString(_ date: Date) -> String {
        isoPlain.string(from: date)
    }

    // MARK: Formatting

    nonisolated(unsafe) private static var formatterCache: [String: DateFormatter] = [:]

    static func format(_ date: Date, _ pattern: String) -> String {
        let formatter: DateFormatter
        if let cached = formatterCache[pattern] {
            formatter = cached
        } else {
            formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            formatterCache[pattern] = formatter
        }
        return formatter.string(from: date)
    }

    /// "6:30 PM"
    static func time(_ date: Date) -> String { format(date, "h:mm a") }

    /// "Today", "Tomorrow" or "Tue"
    static func relativeDay(_ date: Date, now: Date = Date()) -> String {
        if isSameDay(date, now) { return "Today" }
        if isSameDay(date, addDays(1, to: now)) { return "Tomorrow" }
        return format(date, "EEE")
    }
}
