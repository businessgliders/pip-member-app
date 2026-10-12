import SwiftUI

/// The studio logo mark — the pink "P" from the app icon artwork.
/// Uses the original artwork colors, so it reads on both light and dark backgrounds.
struct BrandMark: View {
    var size: CGFloat

    var body: some View {
        Image("AppLogo")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
