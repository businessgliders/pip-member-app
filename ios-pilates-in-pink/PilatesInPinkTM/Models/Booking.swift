import Foundation

/// A member booking with its embedded class session.
nonisolated struct Booking: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let status: String?
    let stationId: String?
    let classSessionId: String
    let bookedAt: String?
    let classSessions: SessionEmbed?

    nonisolated struct SessionEmbed: Decodable, Hashable, Sendable {
        let startsAt: String?
        let endsAt: String?
        let classTypes: ClassTypeEmbed?
    }

    nonisolated struct ClassTypeEmbed: Decodable, Hashable, Sendable {
        let name: String?
        let level: String?
    }

    var startDate: Date { StudioTime.parse(classSessions?.startsAt) ?? .distantPast }
    var endDate: Date { StudioTime.parse(classSessions?.endsAt) ?? startDate }
    var className: String { classSessions?.classTypes?.name ?? "Class" }
    var level: String? { classSessions?.classTypes?.level }
}
