import SwiftUI

/// Root: switches between signed-out and signed-in purely from auth state changes.
/// The animated splash plays once per cold launch, above whichever screen auth resolves to.
struct ContentView: View {
    @State private var auth = AuthStore()
    @State private var handoff = LogoHandoff()
    /// Lives as long as the process: returning from the background never shows the splash again.
    @State private var showsSplash = true

    var body: some View {
        ZStack {
            switch auth.phase {
            case .loading:
                SplashStill()
                    .transition(.opacity)
            case .signedOut:
                WelcomeView()
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
                    .id(auth.userId)
                    .transition(.opacity)
            }

            if showsSplash {
                SplashView(phase: auth.phase) {
                    handoff.isSplashActive = false
                    showsSplash = false
                }
                .zIndex(1)
            }
        }
        .animation(Motion.fade, value: auth.phase)
        .environment(auth)
        .environment(handoff)
        .modifier(CalmMotionProvider())
        .tint(Theme.ink)
    }
}

/// The resting frame of the splash: logo centred in the full screen with the wordmark below.
/// Shown under the splash while auth is still unknown, so the splash can leave on time.
struct SplashStill: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Theme.background
                LogoMark(size: 96)
                    .overlay(alignment: .top) { SplashWordmark(tracking: Motion.splashTrackingTo).offset(y: 96 + 20) }
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pilates in Pink")
    }
}

/// "Pilates in Pink™" + "BRAMPTON", sized to sit under the 96pt logo.
struct SplashWordmark: View {
    var tracking: CGFloat
    var titleOpacity: Double = 1
    var cityOpacity: Double = 1

    var body: some View {
        VStack(spacing: 8) {
            Text("Pilates in Pink™")
                .font(Typo.font(26, .light, relativeTo: .title))
                .foregroundStyle(Theme.ink)
                .modifier(AnimatableTracking(tracking: tracking))
                .opacity(titleOpacity)
            Text("BRAMPTON")
                .font(Typo.font(11, .medium, relativeTo: .caption2))
                .tracking(3)
                .foregroundStyle(Theme.secondaryText)
                .offset(x: 1.5)
                .opacity(cityOpacity)
        }
        .fixedSize()
    }
}

/// Lets letter-spacing ease smoothly.
struct AnimatableTracking: ViewModifier, Animatable {
    var tracking: CGFloat
    var animatableData: CGFloat {
        get { tracking }
        set { tracking = newValue }
    }

    func body(content: Content) -> some View {
        content.tracking(tracking)
    }
}

/// Cold-launch splash. Frame 0 is identical to the launch screen (the PNG logo at 96pt, centred
/// in the full screen on cream). The outline re-traces toward the stem while the fill breathes,
/// the wordmark fades in, then the logo glides to its home on the next screen.
struct SplashView: View {
    let phase: AuthStore.Phase
    let onFinish: () -> Void

    @Environment(LogoHandoff.self) private var handoff
    @Environment(\.calmMotion) private var calm

    @State private var pngOpacity: Double = 1
    @State private var trace: CGFloat = 0
    @State private var ghost: Double = 0
    @State private var fill: Double = 1
    @State private var tracking: CGFloat = Motion.splashTrackingFrom
    @State private var titleOpacity: Double = 0
    @State private var cityOpacity: Double = 0

    // Hand-off
    @State private var isHandingOff = false
    @State private var target: CGRect?
    @State private var targetIsCream = false
    @State private var tilt: Double = 0
    @State private var creamOpacity: Double = 0
    @State private var logoOpacity: Double = 1
    @State private var backgroundOpacity: Double = 1
    @State private var startedAt = Date()
    @State private var didHandOff = false

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let destination = target.map { CGPoint(x: $0.midX, y: $0.midY) } ?? center
            let scale = target.map { $0.width / 96 } ?? 1

            ZStack {
                Theme.background
                    .opacity(backgroundOpacity)

                ZStack {
                    LogoMark(size: 96, trace: trace, fillOpacity: fill, ghost: ghost)
                    LogoMark(size: 96, style: .creamFill)
                        .opacity(creamOpacity)
                    BrandMark(size: 96)
                        .opacity(pngOpacity)
                }
                .overlay(alignment: .top) {
                    SplashWordmark(tracking: tracking, titleOpacity: titleOpacity, cityOpacity: cityOpacity)
                        .offset(y: 96 + 20)
                        .opacity(isHandingOff ? 0 : 1)
                }
                .scaleEffect(isHandingOff ? scale : 1)
                .rotationEffect(.degrees(tilt))
                .position(isHandingOff ? destination : center)
                .opacity(logoOpacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(!isHandingOff)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pilates in Pink")
        .task { await play() }
        .onChange(of: phase) { _, _ in Task { await handOffIfReady() } }
    }

    private func play() async {
        startedAt = Date()
        if calm {
            // Static logo + wordmark, then a cross-fade.
            pngOpacity = 0
            trace = 1
            withAnimation(Motion.fade) {
                titleOpacity = 1
                cityOpacity = 1
                tracking = Motion.splashTrackingTo
            }
        } else {
            withAnimation(.easeInOut(duration: Motion.splashPNGFade)) {
                pngOpacity = 0
                ghost = 0.18
            }
            withAnimation(.easeInOut(duration: Motion.splashTrace)) { trace = 1 }
            withAnimation(.easeInOut(duration: Motion.splashTrace / 2)) { fill = 0.85 }
            withAnimation(.easeInOut(duration: Motion.splashTrace / 2).delay(Motion.splashTrace / 2)) { fill = 1 }
            withAnimation(.easeInOut(duration: Motion.splashWordmarkDuration).delay(Motion.splashWordmarkDelay)) {
                titleOpacity = 1
                tracking = Motion.splashTrackingTo
            }
            withAnimation(.easeInOut(duration: Motion.splashCityDuration).delay(Motion.splashCityDelay)) {
                cityOpacity = 1
            }
        }

        try? await Task.sleep(for: .seconds(Motion.splashMinimum))
        await handOffIfReady()
        try? await Task.sleep(for: .seconds(Motion.splashMaximum - Motion.splashMinimum))
        // Auth still unknown: leave anyway — the resting frame underneath matches this one.
        await handOff(force: true)
    }

    private func handOffIfReady() async {
        guard phase != .loading,
              Date().timeIntervalSince(startedAt) >= Motion.splashMinimum else { return }
        await handOff(force: false)
    }

    private func handOff(force: Bool) async {
        guard !didHandOff else { return }
        didHandOff = true

        // Give the next screen a moment to lay out and report where its logo sits.
        try? await Task.sleep(for: .milliseconds(60))
        let key: LogoHandoff.Target? = switch phase {
        case .signedIn: .home
        case .signedOut: .welcomeVideo
        case .loading: nil
        }
        let frame = key.flatMap { handoff.frames[$0] }

        if calm || frame == nil {
            withAnimation(.easeInOut(duration: Motion.splashHandoff)) {
                backgroundOpacity = 0
                logoOpacity = 0
            }
        } else if key == .welcomeVideo {
            // Signed out: the logo grows into the neon "P" on the video's first frame
            // and dissolves into it as the cream lifts away.
            target = frame
            withAnimation(.easeInOut(duration: Motion.splashHandoff)) {
                isHandingOff = true
                backgroundOpacity = 0
                tilt = Motion.splashVideoTilt
                trace = 1
                fill = 1
            }
            withAnimation(.easeIn(duration: Motion.splashHandoff)) { logoOpacity = 0 }
        } else {
            target = frame
            targetIsCream = key == .home
            withAnimation(.easeInOut(duration: Motion.splashHandoff)) {
                isHandingOff = true
                backgroundOpacity = 0
                trace = 1
                fill = 1
                if targetIsCream { creamOpacity = 1 }
            }
        }
        try? await Task.sleep(for: .seconds(Motion.splashHandoff))
        onFinish()
    }
}

#Preview {
    ContentView()
}
