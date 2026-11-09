import SwiftUI
import UIKit

/// Signed-out experience: logo at the top, the video open in the middle, and the headline
/// grouped with the LOG IN OR SIGN UP pill at the bottom. The pill opens the full-screen
/// sign-in steps over the video.
///
/// Layout rules: the video and gradient live in `.background` and never affect layout.
/// The content is sized by the window's safe area only, and picks its layout from the window's
/// own width (narrow → one column, wide → two columns), so split screen and resizing follow
/// the window, not the device.
struct WelcomeView: View {
    /// The welcome headline — change it here.
    static let headline = "Your reformer\nis waiting."
    /// The line under the headline.
    static let subline = "Reformer Pilates in Brampton."
    /// The label under (or beside) the top mark.
    static let brandLabel = "PILATES IN PINK™"
    /// Windows at least this wide get the two-column layout.
    static let twoColumnWidth: CGFloat = 600

    @Environment(LogoHandoff.self) private var handoff
    @Environment(\.calmMotion) private var calm
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsAuth = false
    @State private var isOnScreen = false
    @State private var showsBrandLabel = false
    @State private var showsHeadline = false
    @State private var showsSubline = false
    @State private var showsActions = false

    private var isPlaying: Bool {
        isOnScreen && scenePhase == .active && !handoff.isSplashActive && !showsAuth
    }

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= Self.twoColumnWidth {
                wideLayout(proxy)
            } else {
                compactLayout(proxy)
            }
        }
        .background { backdrop }
        .overlay {
            if showsAuth {
                AuthFlowView {
                    withAnimation(Motion.choose(Motion.ease, calm: calm)) { showsAuth = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .task(id: handoff.isSplashActive) {
            // The splash logo has landed on the top mark: the label settles in beside it,
            // then the headline, subline and button fade up from the bottom.
            guard !handoff.isSplashActive, !showsHeadline else { return }
            let curve = Motion.choose(Motion.ease, calm: calm)
            withAnimation(Motion.fade) { showsBrandLabel = true }
            try? await Task.sleep(for: .seconds(Motion.welcomeEntranceDelay))
            withAnimation(curve) { showsHeadline = true }
            try? await Task.sleep(for: .seconds(Motion.welcomeEntranceStagger))
            withAnimation(curve) { showsSubline = true }
            try? await Task.sleep(for: .seconds(Motion.welcomeEntranceStagger))
            withAnimation(curve) { showsActions = true }
        }
    }

    // MARK: Backdrop (never affects layout)

    private var backdrop: some View {
        ZStack {
            WelcomeVideoBackground(isActive: isPlaying)
            // Keeps the white mark at the top and the white text at the bottom readable
            // on every frame; the middle stays clear for the video.
            LinearGradient(
                stops: [
                    .init(color: Theme.fixedInk.opacity(0.35), location: 0),
                    .init(color: Theme.fixedInk.opacity(0), location: 0.2),
                    .init(color: Theme.fixedInk.opacity(0), location: 0.5),
                    .init(color: Theme.fixedInk.opacity(0.65), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    // MARK: Compact (portrait / narrow windows)

    private func compactLayout(_ proxy: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                // Top: the mark, with the label 10pt under it.
                VStack(spacing: 10) {
                    mark(size: 40)
                    brandLabel
                }
                .padding(.top, 24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pilates in Pink")

                // Middle: open, so the video shows through.
                Spacer(minLength: 24)

                // Bottom group: headline, subline, then the panel.
                VStack(alignment: .leading, spacing: 0) {
                    headlineGroup
                    signInPill
                        .padding(.top, 28)
                        .riseIn(showsActions)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 460)
                // Above the home indicator — or the keyboard, which shrinks the safe area.
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            .avoidingFold()
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }

    // MARK: Wide (landscape, iPhone Duo inner, iPad, wide split screen)

    private func wideLayout(_ proxy: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Top-left: mark and label side by side.
                HStack(spacing: 12) {
                    mark(size: 32)
                    brandLabel
                }
                .padding(.top, 24)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pilates in Pink")

                Spacer(minLength: 24)

                // Bottom: headline on the left, panel on the right, bottoms aligned;
                // with a fold, the gap between the columns sits on it.
                FoldColumns(spacing: 48, gutter: 24, alignment: .bottom) {
                    headlineGroup
                } trailing: {
                    signInPill
                        .riseIn(showsActions)
                        .frame(maxWidth: 400)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
    }

    // MARK: Pieces

    /// Headline + subline, left-aligned.
    private var headlineGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.headline)
                .font(Typo.font(32, .light, relativeTo: .title))
                .tracking(-0.3)
                .lineSpacing(2)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(.white)
                .riseIn(showsHeadline)
                .accessibilityAddTraits(.isHeader)
            Text(Self.subline)
                .font(Typo.font(15, .regular, relativeTo: .subheadline))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
                .riseIn(showsSubline)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: Theme.fixedInk.opacity(0.25), radius: 12, y: 2)
        .allowsHitTesting(false)
    }

    /// The one entry point: opens the full-screen sign-in steps.
    private var signInPill: some View {
        Button {
            withAnimation(Motion.choose(Motion.ease, calm: calm)) { showsAuth = true }
        } label: {
            Text("LOG IN OR SIGN UP")
        }
        .buttonStyle(CreamPillButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: showsAuth) { _, new in new }
    }

    /// The white mark — where the splash logo lands on a cold launch.
    private func mark(size: CGFloat) -> some View {
        LogoMark(size: size, style: .white)
            .logoHandoffTarget(.welcome)
    }

    private var brandLabel: some View {
        Text(Self.brandLabel)
            .font(Typo.font(12, .medium, relativeTo: .caption))
            .tracking(3)
            .lineLimit(1)
            .foregroundStyle(.white)
            .shadow(color: Theme.fixedInk.opacity(0.25), radius: 8, y: 1)
            .opacity(showsBrandLabel ? 1 : 0)
    }
}

/// Full-width cream pill with ink text — for use over the welcome video in both modes.
struct CreamPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CreamBody(configuration: configuration)
    }

    private struct CreamBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.calmMotion) private var calm
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(Typo.button)
                .tracking(1.8)
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Theme.fixedInk)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 56)
                .background(Theme.cream, in: Capsule())
                .opacity(isEnabled ? (configuration.isPressed ? Motion.pressOpacity : 1) : 0.55)
                .scaleEffect(configuration.isPressed && !calm ? Motion.pressScale : 1)
                .animation(Motion.press, value: configuration.isPressed)
                .contentShape(Capsule())
        }
    }
}
