import Foundation

/// Display-only helper for the cancellation window copy.
/// Deadline = class start − cancellation_window_minutes (always before the class starts).
struct CancellationPolicy {
    let start: Date
    let windowMinutes: Int

    var deadline: Date { start.addingTimeInterval(-Double(windowMinutes) * 60) }

    func isInsideWindow(now: Date = Date()) -> Bool { now >= deadline }

    /// "9 hours", "90 minutes", "1 hour"
    var windowText: String {
        if windowMinutes % 60 == 0 {
            let hours = windowMinutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(windowMinutes) minutes"
    }

    /// "9:30 AM" when on the class day, otherwise "Mon 9:30 PM".
    var deadlineText: String {
        if StudioTime.isSameDay(deadline, start) {
            return StudioTime.time(deadline)
        }
        return StudioTime.format(deadline, "EEE h:mm a")
    }

    func contextLine(now: Date = Date()) -> String {
        if isInsideWindow(now: now) {
            return "This class is within \(windowText) — cancelling later will use your credit."
        }
        return "Free cancellation until \(deadlineText)"
    }
}
