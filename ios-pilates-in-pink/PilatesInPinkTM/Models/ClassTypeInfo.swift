import Foundation

/// A row from `class_types` (id + description only).
nonisolated struct ClassTypeInfo: Decodable, Hashable, Sendable {
    let id: String
    let description: String?
}
