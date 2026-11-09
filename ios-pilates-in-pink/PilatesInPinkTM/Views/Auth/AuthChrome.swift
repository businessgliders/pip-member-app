import SwiftUI
import UIKit

/// Shared look for every sign-in and onboarding step: the welcome poster frame blurred heavily
/// with ink at 70% on top, cream DM Sans, cream pills, a small logo top-left and a close X top-right.

/// The welcome poster, blurred, under 70% ink. Never affects layout.
struct AuthBackdrop: View {
    var body: some View {
        ZStack {
            Color(hex: 0xB0386A)
            if let poster = WelcomeVideo.poster {
                Color.clear
                    .overlay {
                        Image(uiImage: poster)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .blur(radius: 48, opaque: true)
                    .scaleEffect(1.15)
            }
            Theme.fixedInk.opacity(0.7)
            Image("grain")
                .resizable(resizingMode: .tile)
                .opacity(0.08)
                .blendMode(.overlay)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Logo top-left, close X top-right, and (during onboarding) the progress segments under them.
struct AuthHeader: View {
    var progress: Int? = nil
    var progressCount: Int = 4
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                LogoMark(size: 30, style: .cream)
                    .accessibilityLabel("Pilates in Pink")
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.cream)
                        .frame(width: 44, height: 44)
                        .background(Theme.cream.opacity(0.12), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("Close")
            }
            if let progress {
                AuthProgress(current: progress, count: progressCount)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// Four thin segments across the top; finished ones fill cream.
struct AuthProgress: View {
    let current: Int
    let count: Int
    @Environment(\.calmMotion) private var calm

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...count, id: \.self) { index in
                Capsule()
                    .fill(Theme.cream.opacity(index <= current ? 0.95 : 0.22))
                    .frame(height: 3)
            }
        }
        .animation(Motion.choose(Motion.ease, calm: calm), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current) of \(count)")
    }
}

/// One step's body: scrolling content with the buttons pinned under it. The buttons ride
/// above the keyboard (the bottom safe area includes it), so it never covers them.
struct AuthStep<Content: View, Actions: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: 460, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
            .avoidingFold()
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                actions
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .avoidingFold()
        }
    }
}

/// 34pt Medium lowercase headline with tight tracking.
struct AuthTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typo.font(34, .medium, relativeTo: .largeTitle))
            .tracking(-1)
            .foregroundStyle(Theme.cream)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct AuthCaption: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Typo.font(16, .regular, relativeTo: .body))
            .foregroundStyle(Theme.cream.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Rounded translucent field container on the dark backdrop.
struct AuthFieldBox<Content: View>: View {
    var isFocused: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .font(Typo.font(17, .regular, relativeTo: .body))
            .foregroundStyle(Theme.cream)
            .tint(Theme.cream)
            .padding(.horizontal, 18)
            .frame(minHeight: 58)
            .background(Theme.cream.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.cream.opacity(isFocused ? 0.6 : 0.18), lineWidth: 1)
            }
            .animation(Motion.fade, value: isFocused)
    }
}

/// Placeholder text in muted cream.
func authPrompt(_ text: String) -> Text {
    Text(text).foregroundStyle(Theme.cream.opacity(0.45))
}

/// Cream text link for secondary actions.
struct CreamLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.font(15, .regular, relativeTo: .callout))
            .foregroundStyle(Theme.cream)
            .underline(true, color: Theme.cream.opacity(0.35))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}

/// A rounded checkbox with its label; the label can carry links.
struct AuthCheckRow: View {
    @Binding var isOn: Bool
    let label: Text
    var accessibilityText: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                isOn.toggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? Theme.cream : Theme.cream.opacity(0.08))
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Theme.cream.opacity(isOn ? 0 : 0.45), lineWidth: 1.2)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.fixedInk)
                        .opacity(isOn ? 1 : 0)
                        .scaleEffect(isOn ? 1 : 0.6)
                }
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44, alignment: .topLeading)
                .padding(.top, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(Motion.fade, value: isOn)
            .sensoryFeedback(.selection, trigger: isOn)
            .accessibilityLabel(accessibilityText)
            .accessibilityValue(isOn ? "Checked" : "Not checked")
            .accessibilityAddTraits(.isToggle)

            label
                .font(Typo.font(15, .regular, relativeTo: .callout))
                .foregroundStyle(Theme.cream.opacity(0.85))
                .tint(Theme.cream)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, -10)
    }
}

/// Inline message under a field: errors get a soft dot, info an envelope.
struct AuthNotice: View {
    enum Kind: Equatable { case error, info }
    let kind: Kind
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if kind == .error {
                Circle()
                    .fill(Theme.softPink)
                    .frame(width: 6, height: 6)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            } else {
                Image(systemName: "envelope.open").font(.system(size: 13))
            }
            Text(text)
        }
        .font(Typo.font(15, .regular, relativeTo: .callout))
        .foregroundStyle(Theme.cream)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A step's transition: cross-fade and a 12pt slide (a plain fade when motion is calm).
extension AnyTransition {
    static func authStep(calm: Bool) -> AnyTransition {
        if calm { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(x: Motion.authStepSlide)),
            removal: .opacity.combined(with: .offset(x: -Motion.authStepSlide))
        )
    }
}

/// Placeholder legal links — replace with the real pages.
enum LegalLinks {
    static let terms = URL(string: "https://www.pilatesinpinkstudio.com")!
    static let privacy = URL(string: "https://www.pilatesinpinkstudio.com")!
}

/// "I agree to the Terms and Privacy Policy", with both links opening in a Safari sheet
/// (handled by the step through `OpenURLAction`).
var termsAgreementText: Text {
    var string = AttributedString("I agree to the Terms and Privacy Policy")
    if let range = string.range(of: "Terms") {
        string[range].link = LegalLinks.terms
        string[range].underlineStyle = .single
    }
    if let range = string.range(of: "Privacy Policy") {
        string[range].link = LegalLinks.privacy
        string[range].underlineStyle = .single
    }
    return Text(string)
}
