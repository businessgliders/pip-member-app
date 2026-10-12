import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Pilates in Pink brand tokens. Pink is never used for text.
enum Theme {
    static let ink = Color.adaptive(light: 0x1A1418, dark: 0xFBF2F3)
    /// Text placed on top of brand pink — always dark ink, in both modes.
    static let onPink = Color(hex: 0x1A1418)
    static let secondaryText = Color.adaptive(light: 0x7A6E72, dark: 0xB3A6AA)
    static let background = Color.adaptive(light: 0xF6EEE7, dark: 0x1A1418)
    static let gradientTop = Color.adaptive(light: 0xFBE0E2, dark: 0x3A2129)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x272024)
    static let pink = Color(hex: 0xF1889B)
    static let softPink = Color.adaptive(light: 0xF7B1BD, dark: 0x5C3641)
    static let blush = Color.adaptive(light: 0xFBE0E2, dark: 0x3A2830)
    static let caramel = Color.adaptive(light: 0xB67651, dark: 0xDDA683)
    static let caramelSoft = Color.adaptive(light: 0xF4E4D8, dark: 0x3D2C22)
    static let taken = Color.adaptive(light: 0xEDE6E2, dark: 0x342D31)
    static let hairline = Color.adaptive(light: 0xEADFD9, dark: 0x3C3438)
    static let success = Color(hex: 0x3E8E6A)
    static let warning = Color(hex: 0xC9822B)

    static let cardRadius: CGFloat = 24
    static let tabBarClearance: CGFloat = 110
    static let spring: Animation = .spring(response: 0.38, dampingFraction: 0.78)
}

// MARK: - Backgrounds & surfaces

struct ScreenBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Theme.background
            LinearGradient(colors: [Theme.gradientTop, Theme.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 420)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func cardStyle(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}

// MARK: - Typography

struct ScreenTitle: View {
    let text: String
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 38

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .heavy))
            .tracking(-1.2)
            .foregroundStyle(Theme.ink)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Buttons

struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        PillButton(configuration: configuration, kind: kind)
    }

    private struct PillButton: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(kind == .primary ? Theme.onPink : Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.horizontal, 20)
                .background {
                    if kind == .primary {
                        Capsule().fill(
                            LinearGradient(colors: [Color(hex: 0xF49DAD), Theme.pink], startPoint: .top, endPoint: .bottom)
                        )
                    } else {
                        Capsule().fill(Theme.blush)
                    }
                }
                .shadow(color: kind == .primary && isEnabled ? Theme.pink.opacity(0.35) : .clear, radius: 14, x: 0, y: 6)
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
                .contentShape(Capsule())
        }
    }
}

struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Chips

struct Chip: View {
    enum Style { case soft, caramel, outline, blush }
    let text: String
    var style: Style = .soft
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            if let systemImage {
                Image(systemName: systemImage).font(.caption.weight(.bold))
            }
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background {
            switch style {
            case .soft: Capsule().fill(Theme.softPink)
            case .caramel: Capsule().fill(Theme.caramelSoft)
            case .blush: Capsule().fill(Theme.blush)
            case .outline: Capsule().strokeBorder(Theme.hairline, lineWidth: 1)
            }
        }
    }

    private var foreground: Color {
        switch style {
        case .soft, .blush: Theme.ink
        case .caramel: Theme.caramel
        case .outline: Theme.secondaryText
        }
    }
}

// MARK: - Liquid glass helper

struct GlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
        }
    }
}
