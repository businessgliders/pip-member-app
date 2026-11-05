import SwiftUI

/// Liquid Glass on iOS 26, ultra-thin material with a hairline border before that.
struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    var dark: Bool = false
    var interactive: Bool = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(glass, in: shape)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if dark { shape.fill(Color.black.opacity(0.22)) }
                    }
                    .environment(\.colorScheme, dark ? .dark : .light)
                }
                .overlay(shape.stroke(Color.white.opacity(dark ? 0.18 : 0.45), lineWidth: 0.5))
        }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var g: Glass = dark ? .regular.tint(Color.black.opacity(0.28)) : .regular
        if interactive { g = g.interactive() }
        return g
    }
}

extension View {
    func glass<S: Shape>(_ shape: S, dark: Bool = false, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, dark: dark, interactive: interactive))
    }
}

/// 44pt circular glass button (back, close, notifications, profile, share).
struct GlassCircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PressableCardStyle())
        .glass(Circle(), interactive: true)
        .accessibilityLabel(label)
    }
}

/// Glass circle with custom content (initials).
struct GlassCircle<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .frame(width: 44, height: 44)
            .glass(Circle(), interactive: true)
    }
}

/// Translucent dark glass pill with white UPPERCASE tracked text — for labels on photos.
struct PhotoLabelPill: View {
    let text: String
    var size: CGFloat = 11

    var body: some View {
        Text(text.uppercased())
            .font(Typo.font(size, .medium, relativeTo: .caption))
            .tracking(1.5)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glass(Capsule(), dark: true)
    }
}
