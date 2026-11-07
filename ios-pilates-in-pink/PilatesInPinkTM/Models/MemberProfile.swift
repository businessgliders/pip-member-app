import Foundation

/// The signed-in member's row from `get_my_profile` — the source of truth for name and member id
/// (auth metadata is empty for staff-created, imported and code sign-in members).
nonisolated struct MemberProfile: Decodable, Equatable, Sendable {
    let profileId: String
    let firstName: String?
    let lastName: String?
    let email: String?
    let phone: String?
}

/// Resolved name for display: profile names first, then auth metadata, then the email's local part.
nonisolated struct MemberIdentity: Equatable, Sendable {
    let firstName: String
    let lastName: String
    let email: String

    init(profile: MemberProfile?, metadataFirst: String, metadataLast: String, authEmail: String) {
        let profileFirst = Self.clean(profile?.firstName)
        let profileLast = Self.clean(profile?.lastName)
        let metaFirst = Self.clean(metadataFirst)
        let metaLast = Self.clean(metadataLast)
        let profileEmail = Self.clean(profile?.email)
        email = profileEmail.isEmpty ? Self.clean(authEmail) : profileEmail

        if !profileFirst.isEmpty || !profileLast.isEmpty {
            firstName = profileFirst
            lastName = profileLast
        } else if !metaFirst.isEmpty || !metaLast.isEmpty {
            firstName = metaFirst
            lastName = metaLast
        } else {
            firstName = email.split(separator: "@", maxSplits: 1).first.map(String.init) ?? ""
            lastName = ""
        }
    }

    var displayName: String {
        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Member" : name
    }

    /// Card greeting: first name, or the full display name when there's no first name.
    var shortName: String { firstName.isEmpty ? displayName : firstName }

    var initials: String {
        let letters = [firstName.first, lastName.first].compactMap { $0 }
        if !letters.isEmpty { return String(letters).uppercased() }
        if let e = email.first { return String(e).uppercased() }
        return ""
    }

    private static func clean(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
