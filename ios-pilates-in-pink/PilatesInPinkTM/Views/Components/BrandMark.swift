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

/// Mark + "Pilates in Pink™" wordmark.
struct Wordmark: View {
    var color: Color = Theme.ink
    var markSize: CGFloat = 30
    var textSize: CGFloat = 17

    var body: some View {
        HStack(spacing: 10) {
            BrandMark(size: markSize)
            Text("Pilates in Pink™")
                .font(Typo.font(textSize, .light, relativeTo: .headline))
                .tracking(0.6)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pilates in Pink")
    }
}
