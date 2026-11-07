import SwiftUI

/// Signed-out experience: the cinematic video welcome, with sign-in pushed on top.
struct WelcomeView: View {
    @State private var path: [WelcomeRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            VideoWelcomeScreen { path.append(.signIn) }
                .navigationDestination(for: WelcomeRoute.self) { _ in
                    SignInView()
                }
        }
    }
}

enum WelcomeRoute: Hashable { case signIn }

/// Full-bleed looping video, a soft ink gradient, the headline and GET STARTED.
struct VideoWelcomeScreen: View {
    /// The welcome headline — change it here.
    static let headline = "Your reformer\nis waiting."

    let onGetStarted: () -> Void

    @Environment(LogoHandoff.self) private var handoff
    @Environment(\.calmMotion) private var calm
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var showsHeadline = false
    @State private var showsActions = false

    private var isPlaying: Bool {
        isOnScreen && scenePhase == .active && !handoff.isSplashActive
    }

    var body: some View {
        ZStack {
            WelcomeVideoBackground(isActive: isPlaying)
            gradient
            neonTarget
            content
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarRole(.editor) // the pushed screen shows a bare chevron, no "Back" title
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .task(id: handoff.isSplashActive) {
            guard !handoff.isSplashActive, !showsHeadline else { return }
            try? await Task.sleep(for: .seconds(Motion.welcomeHeadlineDelay))
            withAnimation(Motion.choose(Motion.easeLong, calm: calm)) { showsHeadline = true }
            try? await Task.sleep(for: .seconds(Motion.welcomeButtonStagger))
            withAnimation(Motion.choose(Motion.easeLong, calm: calm)) { showsActions = true }
        }
    }

    private var gradient: some View {
        LinearGradient(
            stops: [
                .init(color: Theme.fixedInk.opacity(0), location: 0),
                .init(color: Theme.fixedInk.opacity(0.25), location: 0.5),
                .init(color: Theme.fixedInk.opacity(0.55), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Invisible square over the neon "P", so the splash logo knows where to land.
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

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(Self.headline)
                .font(Typo.font(28, .light, relativeTo: .title))
                .tracking(-0.3)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: Theme.fixedInk.opacity(0.25), radius: 12, y: 2)
                .riseIn(showsHeadline)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 32)

            VStack(spacing: 22) {
                Button(action: onGetStarted) {
                    Text("Get started")
                }
                .buttonStyle(CreamPillButtonStyle())
                .accessibilityHint("Sign in or create an account")

                LogoMark(size: 28, style: .white)
                    .accessibilityElement()
                    .accessibilityLabel("Pilates in Pink")
            }
            .riseIn(showsActions)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
        .avoidingFold()
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
                .opacity(configuration.isPressed ? Motion.pressOpacity : 1)
                .scaleEffect(configuration.isPressed && !calm ? Motion.pressScale : 1)
                .animation(Motion.press, value: configuration.isPressed)
                .contentShape(Capsule())
        }
    }
}
