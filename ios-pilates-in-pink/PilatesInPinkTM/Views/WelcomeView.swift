import SwiftUI
import UIKit

/// Signed-out experience: the looping video with the headline and one glass sign-in panel.
///
/// Layout rules: the video, gradient and splash target live in `.background` and never
/// affect layout. The content is sized by the window's safe area only, and picks its layout
/// from the window's own width (narrow → one column, wide → two columns), so split screen and
/// resizing follow the window, not the device.
struct WelcomeView: View {
    /// The welcome headline — change it here.
    static let headline = "Your reformer\nis waiting."
    /// Windows at least this wide get the two-column layout.
    static let twoColumnWidth: CGFloat = 600

    @Environment(LogoHandoff.self) private var handoff
    @Environment(\.calmMotion) private var calm
    @Environment(\.scenePhase) private var scenePhase
    @State private var flow = SignInFlow()
    @State private var isOnScreen = false
    @State private var showsHeadline = false
    @State private var showsActions = false
    @State private var keyboardVisible = false

    private var isPlaying: Bool {
        isOnScreen && scenePhase == .active && !handoff.isSplashActive
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
        .onAppear {
            isOnScreen = true
            flow.calm = calm
        }
        .onDisappear { isOnScreen = false }
        .onChange(of: calm) { _, new in flow.calm = new }
        .task(id: handoff.isSplashActive) {
            guard !handoff.isSplashActive, !showsHeadline else { return }
            try? await Task.sleep(for: .seconds(Motion.welcomeHeadlineDelay))
            withAnimation(Motion.choose(Motion.easeLong, calm: calm)) { showsHeadline = true }
            try? await Task.sleep(for: .seconds(Motion.welcomeButtonStagger))
            withAnimation(Motion.choose(Motion.easeLong, calm: calm)) { showsActions = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            guard frame.height > 120 else { return } // ignore the iPad hardware-keyboard bar
            withAnimation(Motion.welcomeKeyboardFade) { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(Motion.welcomeKeyboardFade) { keyboardVisible = false }
        }
    }

    // MARK: Backdrop (never affects layout)

    private var backdrop: some View {
        ZStack {
            WelcomeVideoBackground(isActive: isPlaying)
            LinearGradient(
                stops: [
                    .init(color: Theme.fixedInk.opacity(0), location: 0),
                    .init(color: Theme.fixedInk.opacity(0.25), location: 0.5),
                    .init(color: Theme.fixedInk.opacity(0.55), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            neonTarget
        }
        .ignoresSafeArea()
    }

    /// Invisible square over the neon "P", measured on the full window, so the splash logo
    /// knows where to land.
    private var neonTarget: some View {
        GeometryReader { proxy in
            let frame = WelcomeVideo.neonFrame(in: proxy.size)
            Color.clear
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .logoHandoffTarget(.welcomeVideo)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Tapping the video (outside the panel) collapses it and puts the keyboard away.
    private var videoTapCatcher: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture { flow.collapse() }
            .accessibilityHidden(true)
    }

    // MARK: Compact (portrait / narrow windows)

    private func compactLayout(_ proxy: GeometryProxy) -> some View {
        let insets = proxy.safeAreaInsets
        let windowHeight = proxy.size.height + insets.top + insets.bottom
        // Headline centred about 38% down the window (it's ~2 lines ≈ 72pt tall).
        let headlineGap = max(12, windowHeight * 0.38 - insets.top - 36)

        return ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 12)
                    .frame(maxHeight: keyboardVisible ? 12 : headlineGap)
                    .layoutPriority(1)
                headline(alignment: .center, size: 28)
                    .opacity(keyboardVisible ? 0 : 1)
                    .frame(height: keyboardVisible ? 0 : nil, alignment: .top)
                Spacer(minLength: 28)
                SignInPanel(flow: flow)
                    .riseIn(showsActions)
                if !keyboardVisible {
                    logo
                        .padding(.top, 12)
                        .riseIn(showsActions)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, keyboardVisible ? 16 : 0)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            .avoidingFold()
            .background { videoTapCatcher }
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Wide (landscape, iPhone Duo inner, iPad)

    private func wideLayout(_ proxy: GeometryProxy) -> some View {
        FoldColumns(spacing: 48, gutter: 24) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 16)
                headline(alignment: .leading, size: 32)
                Spacer(minLength: 16)
                logo
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.vertical, 24)
            .background { videoTapCatcher }
        } trailing: {
            ScrollView {
                SignInPanel(flow: flow)
                    .riseIn(showsActions)
                    .frame(maxWidth: 400)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                    .background { videoTapCatcher }
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .frame(height: proxy.size.height)
        }
        .padding(.horizontal, 32)
        .frame(width: proxy.size.width, height: proxy.size.height)
    }

    // MARK: Pieces

    private func headline(alignment: TextAlignment, size: CGFloat) -> some View {
        Text(Self.headline)
            .font(Typo.font(size, .light, relativeTo: .title))
            .tracking(-0.3)
            .lineSpacing(2)
            .multilineTextAlignment(alignment)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
            .shadow(color: Theme.fixedInk.opacity(0.25), radius: 12, y: 2)
            .riseIn(showsHeadline)
            .accessibilityAddTraits(.isHeader)
            .allowsHitTesting(false)
    }

    private var logo: some View {
        LogoMark(size: 28, style: .white)
            .accessibilityElement()
            .accessibilityLabel("Pilates in Pink")
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
