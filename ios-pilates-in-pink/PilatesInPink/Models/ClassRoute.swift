import Foundation

/// Navigation value that opens a class detail screen.
nonisolated struct ClassRoute: Hashable, Sendable {
    let sessionId: String
    let startsAt: Date
}

/// Payload for the "You're booked" sheet.
struct BookingConfirmation: Identifiable {
    let id = UUID()
    let className: String
    let reformerNumber: Int
    let start: Date
    let end: Date

    var summary: String {
        "Reformer \(reformerNumber) · \(StudioTime.format(start, "EEE MMM d")) · \(StudioTime.time(start))"
    }
}
