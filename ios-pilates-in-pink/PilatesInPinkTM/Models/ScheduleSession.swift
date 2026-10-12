import Foundation

/// A row from `get_schedule`.
nonisolated struct ScheduleSession: Decodable, Identifiable, Hashable, Sendable {
    let sessionId: String
    let startsAt: String
    let endsAt: String
    let status: String?
    let classTypeId: String?
    let classCode: String?
    let className: String?
    let classLevel: String?
    let instructorProfileId: String?
    let instructorName: String?
    let isSubstitute: Bool?
    let capacity: Int?
    let bookedCount: Int?
    let myBookingId: String?
    let myWaitlistEntryId: String?

    var id: String { sessionId }
    var startDate: Date { StudioTime.parse(startsAt) ?? .distantPast }
    var endDate: Date { StudioTime.parse(endsAt) ?? startDate }
    var name: String { className ?? "Class" }
    var isCancelled: Bool { status == "cancelled" }
    var isSub: Bool { isSubstitute ?? false }
    var durationMinutes: Int { max(0, Int(endDate.timeIntervalSince(startDate) / 60)) }
    var spotsLeft: Int { max(0, (capacity ?? 0) - (bookedCount ?? 0)) }
    var isFull: Bool { spotsLeft == 0 }
    var isBooked: Bool { myBookingId != nil }
    var isWaitlisted: Bool { myWaitlistEntryId != nil }
    var hasStarted: Bool { startDate <= Date() }
}
