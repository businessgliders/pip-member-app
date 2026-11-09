import Foundation

/// One row of `home_banners`. Copy, image and action all come from the studio's database.
nonisolated struct HomeBanner: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let sortOrder: Int?
    let imagePath: String?
    let fallbackAsset: String?
    let headline: String?
    let subtitle: String?
    let buttonLabel: String?
    let actionType: String?
    let actionValue: String?

    static let storageBase = "https://ouckdjvsxozksskinkzf.supabase.co/storage/v1/object/public/banners/"

    /// Public image in the `banners` bucket, when set.
    var imageURL: URL? {
        guard let path = imagePath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(string: Self.storageBase + encoded)
    }

    var trimmedButtonLabel: String? {
        guard let label = buttonLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty else { return nil }
        return label
    }

    enum Action: Equatable, Sendable {
        case classes(ClassFamily?)
        case me
        case credits
        case url(URL)
        case none
    }

    var action: Action {
        let value = actionValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch actionType?.lowercased() {
        case "classes": return .classes(nil)
        case "class_family": return .classes(ClassFamily.from(key: value))
        case "me": return .me
        case "credits": return .credits
        case "url":
            if let url = URL(string: value), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" {
                return .url(url)
            }
            return .none
        default: return .none
        }
    }
}
