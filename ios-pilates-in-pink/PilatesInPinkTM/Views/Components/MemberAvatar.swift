import SwiftUI

/// The member's photo (from the private avatars bucket) clipped to a circle, or `fallback`
/// (their initials) when there's no photo or it can't load.
struct MemberAvatar<Fallback: View>: View {
    let path: String?
    @ViewBuilder var fallback: () -> Fallback

    @State private var image: UIImage?
    private var photos: MemberPhotoCache { MemberPhotoCache.shared }

    private var cleanPath: String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
        return path
    }

    var body: some View {
        ZStack {
            if let image, cleanPath != nil {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                fallback()
            }
        }
        .clipShape(Circle())
        .animation(Motion.fade, value: image)
        .task(id: "\(cleanPath ?? "")#\(photos.version)") {
            guard let cleanPath else {
                image = nil
                return
            }
            if let cached = photos.cached(path: cleanPath) { image = cached }
            if let loaded = await photos.load(path: cleanPath) { image = loaded }
        }
        .accessibilityHidden(true)
    }
}
