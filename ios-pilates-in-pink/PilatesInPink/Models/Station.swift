import Foundation

/// A reformer in the room.
nonisolated struct Station: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let number: Int
    let rowNum: Int?
    let colNum: Int?
    let isActive: Bool?

    var row: Int { rowNum ?? ((number - 1) / 2 + 1) }
    var column: Int { colNum ?? ((number - 1) % 2 + 1) }
    var isInService: Bool { isActive ?? true }
}

/// A row from `get_taken_stations`.
nonisolated struct TakenStation: Decodable, Hashable, Sendable {
    let stationId: String
    let stationNumber: Int?
    let isMine: Bool?
}
