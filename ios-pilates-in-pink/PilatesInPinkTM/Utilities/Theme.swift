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
    init(hex: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: opacity))
    }

    static func adaptive(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

/// Pilates in Pink™ brand tokens — quiet members' club direction.
/// Pink is an accent fill only (never text); text on pink is always ink.
enum Theme {
    // Text
    static let ink = Color.adaptive(light: 0x1A1418, dark: 0xF6EEE7)
    static let secondaryText = Color.adaptive(light: 0x7A6E72, dark: 0xB3A6AA)
    /// Text placed on top of any pink fill — always dark ink, in both modes.
    static let onPink = Color(hex: 0x1A1418)

    // Surfaces
    static let background = Color.adaptive(light: 0xF6EEE7, dark: 0x1A1418)
    static let card = Color.adaptive(light: 0xFBF8F4, dark: 0x262024)
    static let hairline = Color.adaptive(light: 0x1A1418, dark: 0xF6EEE7, lightAlpha: 0.10, darkAlpha: 0.12)
    static let taken = Color.adaptive(light: 0xECE4DE, dark: 0x332B2F)

    // Primary action: ink fill + cream label (inverts in dark mode)
    static let primaryFill = ink
    static let primaryLabel = background

    // Accents
    static let pink = Color(hex: 0xF1889B)
    static let softPink = Color(hex: 0xF7B1BD)
    static let blush = Color.adaptive(light: 0xFBE0E2, dark: 0x3A2830)
    static let caramel = Color.adaptive(light: 0xB67651, dark: 0xDDA683)
    static let cream = Color(hex: 0xF6EEE7)
    static let fixedInk = Color(hex: 0x1A1418)

    static let cardRadius: CGFloat = 20
    static let sheetRadius: CGFloat = 28
    static let gap: CGFloat = 12
    static let readableWidth: CGFloat = 680
    static let spring: Animation = Motion.spring
    static let softSpring: Animation = Motion.softSpring
}

// MARK: - Motion (quiet five-star hotel)

/// Every timing and curve in the app lives here.
/// Rules: 0.35–0.8s, easeInOut or springs with damping ≥ 0.85 (no overshoot), content rises 8–12pt,
/// one attention animation at a time, and nothing ever blocks a tap.
/// Reduce Motion and Low Power Mode turn every movement into a short cross-fade (`calm`).
enum Motion {
    // Durations
    static let short: Double = 0.35
    static let standard: Double = 0.5
    static let long: Double = 0.6
    static let longest: Double = 0.8

    // Curves
    static let fade: Animation = .easeInOut(duration: short)
    static let ease: Animation = .easeInOut(duration: standard)
    static let easeLong: Animation = .easeInOut(duration: long)
    static let spring: Animation = .spring(response: 0.45, dampingFraction: 0.88)
    static let softSpring: Animation = .spring(response: 0.6, dampingFraction: 0.92)
    /// Press feedback: scale 0.98, slightly dimmed, settles back without overshoot.
    static let press: Animation = .spring(response: 0.35, dampingFraction: 0.9)
    static let pressScale: CGFloat = 0.98
    static let pressOpacity: Double = 0.88

    // Distances
    /// How far content rises as it fades in.
    static let rise: CGFloat = 10

    // Splash
    static let splashTrace: Double = 0.6
    static let splashPNGFade: Double = 0.2
    static let splashWordmarkDelay: Double = 0.4
    static let splashWordmarkDuration: Double = 0.5
    static let splashCityDelay: Double = 0.62
    static let splashCityDuration: Double = 0.35
    static let splashMinimum: Double = 0.9
    static let splashMaximum: Double = 1.6
    static let splashHandoff: Double = 0.5
    static let splashTrackingFrom: CGFloat = 4
    static let splashTrackingTo: CGFloat = 0.6
    /// The neon "P" in the welcome video leans slightly; the splash logo tilts to meet it.
    static let splashVideoTilt: Double = -11

    // Welcome (signed out)
    static let welcomeHeadlineDelay: Double = 0.6
    static let welcomeButtonStagger: Double = 0.15
    /// Sign-in panel expanding/collapsing and changing steps (height + opacity).
    static let welcomePanel: Animation = .easeInOut(duration: 0.45)
    /// Headline fading out while the keyboard is up (0.3s, as specified).
    static let welcomeKeyboardFade: Animation = .easeInOut(duration: 0.3)

    // Logo
    static let refreshTrace: Double = 1.2
    static let refreshTraceAnimation: Animation = .easeInOut(duration: refreshTrace)
    static let bookingJoin: Animation = .easeInOut(duration: long)
    static let bookingSeparation: CGFloat = 10
    static let bookingGlowFade: Animation = .easeInOut(duration: longest)
    static let detailStagger: Double = 0.06

    // Reformer select (0.3s, as specified for the centre-out fill)
    static let tileFill: Animation = .easeInOut(duration: 0.3)

    // Home
    static let heroPushInDuration: Double = 9
    static let heroSlideInterval: Double = 6
    static let heroSlideChange: Animation = .easeInOut(duration: longest)
    static let heroTextDelay: Double = 0.2
    static let sectionStagger: Double = 0.07

    // Skeleton shimmer
    static let shimmerSweep: Double = 1.6

    /// The requested animation, or a short cross-fade when motion should be calm.
    static func choose(_ animation: Animation, calm: Bool) -> Animation {
        calm ? fade : animation
    }

    /// A gentle fade + rise, or a plain fade when calm.
    static func rise(calm: Bool) -> AnyTransition {
        calm ? .opacity : .opacity.combined(with: .offset(y: rise))
    }
}

/// Watches Low Power Mode so it can be treated like Reduce Motion.
@Observable
final class LowPowerMonitor {
    static let shared = LowPowerMonitor()
    private(set) var isOn: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            let value = ProcessInfo.processInfo.isLowPowerModeEnabled
            Task { @MainActor in self?.isOn = value }
        }
    }
}

extension EnvironmentValues {
    /// True when Reduce Motion or Low Power Mode is on: movement becomes a short cross-fade.
    @Entry var calmMotion: Bool = false
}

/// Applied once at the root; publishes `calmMotion` to the whole app.
struct CalmMotionProvider: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let power = LowPowerMonitor.shared

    func body(content: Content) -> some View {
        content.environment(\.calmMotion, reduceMotion || power.isOn)
    }
}

/// Fades and rises content once, after an optional delay. Never blocks taps.
struct RiseIn: ViewModifier {
    var isVisible: Bool
    @Environment(\.calmMotion) private var calm

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || calm ? 0 : Motion.rise)
    }
}

extension View {
    func riseIn(_ isVisible: Bool) -> some View { modifier(RiseIn(isVisible: isVisible)) }
}

// MARK: - Typography (DM Sans, SF Pro fallback, Dynamic Type)

enum DMWeight {
    case light, regular, medium

    var postScriptName: String {
        switch self {
        case .light: "DMSans-Light"
        case .regular: "DMSans-Regular"
        case .medium: "DMSans-Medium"
        }
    }

    var systemWeight: Font.Weight {
        switch self {
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        }
    }
}

enum Typo {
    static func font(_ size: CGFloat, _ weight: DMWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        if FontRegistrar.isAvailable {
            return .custom(weight.postScriptName, size: size, relativeTo: style)
        }
        let scaled = UIFontMetrics(forTextStyle: style.uiTextStyle).scaledValue(for: size)
        return .system(size: scaled, weight: weight.systemWeight)
    }

    static var screenTitle: Font { font(32, .light, relativeTo: .largeTitle) }
    static var sectionHeader: Font { font(20, .medium, relativeTo: .title3) }
    static var body: Font { font(16, .regular, relativeTo: .body) }
    static var bodyLarge: Font { font(17, .regular, relativeTo: .body) }
    static var secondary: Font { font(14, .regular, relativeTo: .subheadline) }
    static var label: Font { font(12, .medium, relativeTo: .caption) }
    static var button: Font { font(14, .medium, relativeTo: .callout) }
}

extension Font.TextStyle {
    var uiTextStyle: UIFont.TextStyle {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

/// Small UPPERCASE tracked label ("THURSDAY, NOV 5", "OBSESSED MEMBER").
struct EyebrowText: View {
    let text: String
    var color: Color = Theme.secondaryText
    var size: CGFloat = 12

    init(_ text: String, color: Color = Theme.secondaryText, size: CGFloat = 12) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(text.uppercased())
            .font(Typo.font(size, .medium, relativeTo: .caption))
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

struct ScreenTitle: View {
    let text: String
    var size: CGFloat = 32

    var body: some View {
        Text(text)
            .font(Typo.font(size, .light, relativeTo: .largeTitle))
            .tracking(-0.4)
            .foregroundStyle(Theme.ink)
            .lineLimit(3)
            .minimumScaleFactor(0.75)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Typo.sectionHeader)
            .foregroundStyle(Theme.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Surfaces

extension View {
    /// Warm-white card, radius 20, no shadow.
    func cardStyle(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    /// Centers content and caps it at a readable width (iPad).
    func readableWidth(_ width: CGFloat = Theme.readableWidth) -> some View {
        self.frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

// MARK: - Buttons

/// Full-width 56pt buttons with UPPERCASE tracked labels.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        PillButtonBody(configuration: configuration, kind: kind)
    }

    private struct PillButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let kind: Kind
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.calmMotion) private var calm

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            configuration.label
                .font(Typo.button)
                .tracking(1.6)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(kind == .primary ? Theme.primaryLabel : Theme.ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .padding(.horizontal, 18)
                .background {
                    if kind == .primary {
                        shape.fill(Theme.primaryFill)
                    } else {
                        shape.fill(Theme.card).overlay(shape.strokeBorder(Theme.hairline, lineWidth: 1))
                    }
                }
                .opacity(isEnabled ? (configuration.isPressed ? Motion.pressOpacity : 1) : 0.4)
                .scaleEffect(configuration.isPressed && !calm ? Motion.pressScale : 1)
                .animation(Motion.press, value: configuration.isPressed)
                .contentShape(shape)
        }
    }
}

/// Quiet text button ("Cancel booking").
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(Typo.font(15, .regular, relativeTo: .callout))
            .foregroundStyle(Theme.ink)
            .underline(true, color: Theme.hairline)
            .frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}

/// Tiles, photos and rows: scale 0.98, slightly dimmed, settles back.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        PressBody(configuration: configuration)
    }

    private struct PressBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.calmMotion) private var calm

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed && !calm ? Motion.pressScale : 1)
                .opacity(configuration.isPressed ? Motion.pressOpacity : 1)
                .animation(Motion.press, value: configuration.isPressed)
        }
    }
}

// MARK: - Chips

struct Chip: View {
    enum Style { case pink, soft, blush, outline, caramel }
    let text: String
    var style: Style = .soft
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 10, weight: .semibold))
            }
        }
        .font(Typo.font(13, .medium, relativeTo: .footnote))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background {
            switch style {
            case .pink: Capsule().fill(Theme.pink)
            case .soft: Capsule().fill(Theme.softPink)
            case .blush: Capsule().fill(Theme.blush)
            case .caramel: Capsule().fill(Theme.caramel.opacity(0.12))
            case .outline: Capsule().strokeBorder(Theme.hairline, lineWidth: 1)
            }
        }
    }

    private var foreground: Color {
        switch style {
        case .pink, .soft: Theme.onPink
        case .blush: Theme.ink
        case .caramel: Theme.caramel
        case .outline: Theme.secondaryText
        }
    }
}
