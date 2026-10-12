import Foundation

nonisolated struct StudioSettings: Decodable, Equatable, Sendable {
    let memberBookingHorizonDays: Int?
    /// 0 = Sunday … 6 = Saturday.
    let weekStartDay: Int
    let cancellationWindowMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case memberBookingHorizonDays, weekStartDay, cancellationWindowMinutes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        memberBookingHorizonDays = try? c.decodeIfPresent(Int.self, forKey: .memberBookingHorizonDays)
        cancellationWindowMinutes = try? c.decodeIfPresent(Int.self, forKey: .cancellationWindowMinutes)
        if let number = try? c.decodeIfPresent(Int.self, forKey: .weekStartDay) {
            weekStartDay = ((number % 7) + 7) % 7
        } else if let name = try? c.decodeIfPresent(String.self, forKey: .weekStartDay) {
            let names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
            let prefix = String(name.lowercased().prefix(3))
            weekStartDay = names.firstIndex(of: prefix) ?? 0
        } else {
            weekStartDay = 0
        }
    }
}
