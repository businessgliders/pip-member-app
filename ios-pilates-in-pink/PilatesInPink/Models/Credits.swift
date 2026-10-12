import Foundation

/// A row from `get_my_credits`.
nonisolated struct Credits: Decodable, Equatable, Sendable {
    let creditsAvailable: Double?
    let guestPassesAvailable: Double?
    let hasUnlimited: Bool?
    let membershipName: String?
    let membershipRenewsAt: String?
    let nextCreditExpiry: String?

    var isUnlimited: Bool { hasUnlimited ?? false }
    var creditCount: Int { Int((creditsAvailable ?? 0).rounded()) }
    var guestPassCount: Int { Int((guestPassesAvailable ?? 0).rounded()) }
    var renewsDate: Date? { StudioTime.parse(membershipRenewsAt) }
    var expiryDate: Date? { StudioTime.parse(nextCreditExpiry) }

    /// "Unlimited", "1 credit", "5 credits"
    var chipLabel: String {
        if isUnlimited { return "Unlimited" }
        return creditCount == 1 ? "1 credit" : "\(creditCount) credits"
    }
}
