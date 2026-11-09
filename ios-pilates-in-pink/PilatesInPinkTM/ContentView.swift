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
                if let userId = auth.userId {
                    SignedInRoot(userId: userId, isFresh: auth.isFreshSignIn)
                        .id(userId)
                        .transition(.opacity)
                }
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

/// Signed in: checks whether the member still needs setup (C–F), then shows Home, with the
/// one-time welcome finale (G) over it after a fresh sign-in or after setup.
struct SignedInRoot: View {
    let userId: UUID
    let isFresh: Bool

    private enum Stage: Equatable { case checking, onboarding(OnboardingView.Step), ready }

    @Environment(\.calmMotion) private var calm
    @State private var stage: Stage
    @State private var profile: MemberProfile?
    @State private var showsFinale = false
    /// Home sits slightly small and blurred under the finale, then settles as it leaves.
    @State private var homeSettled = true

    init(userId: UUID, isFresh: Bool) {
        self.userId = userId
        self.isFresh = isFresh
        let onboarded = UserDefaults.standard.bool(forKey: Self.onboardedKey(userId))
        _stage = State(initialValue: (!isFresh && onboarded) ? .ready : .checking)
    }

    private static func onboardedKey(_ id: UUID) -> String { "onboarded.\(id.uuidString.lowercased())" }
    private static func finaleKey(_ id: UUID) -> String { "finaleShown.\(id.uuidString.lowercased())" }

    var body: some View {
        ZStack {
            switch stage {
            case .checking:
                Group {
                    if isFresh {
                        ZStack {
                            AuthBackdrop()
                            ProgressView().tint(Theme.cream)
                        }
                    } else {
                        SplashStill()
                    }
                }
                .transition(.opacity)
                .task { await check() }
            case .onboarding(let start):
                OnboardingView(profile: profile, userId: userId, start: start) {
                    finishOnboarding()
                }
                .transition(.opacity)
            case .ready:
                MainTabView()
                    .scaleEffect(homeSettled || calm ? 1 : 0.94)
                    .blur(radius: homeSettled || calm ? 0 : 12)
                    .transition(.opacity)
            }

            if showsFinale {
                FinaleView {
                    withAnimation(.easeInOut(duration: Motion.finaleExit)) { homeSettled = true }
                } onFinish: {
                    showsFinale = false
                }
                .zIndex(2)
                .transition(.opacity)
            }
        }
        .animation(Motion.fade, value: stage)
    }

    private func check() async {
        let service = StudioService()
        do {
            let fetched = try await service.profile()
            profile = fetched
            if fetched?.needsOnboarding == true {
                if let pending = OnboardingHandoff.pending {
                    // Just created an account with name + consent: save it, start at the photo.
                    OnboardingHandoff.pending = nil
                    try? await service.updateProfile(firstName: pending.firstName,
                                                     lastName: pending.lastName,
                                                     marketing: pending.marketing)
                    stage = .onboarding(.photo)
                } else {
                    stage = .onboarding(.name)
                }
                return
            }
            if let pending = OnboardingHandoff.pending {
                OnboardingHandoff.pending = nil
                try? await service.updateProfile(firstName: pending.firstName,
                                                 lastName: pending.lastName,
                                                 marketing: pending.marketing)
                stage = .onboarding(.photo)
                return
            }
            UserDefaults.standard.set(true, forKey: Self.onboardedKey(userId))
        } catch {
            print("Profile check failed: \(error.localizedDescription)")
        }
        becomeReady(withFinale: isFresh && !UserDefaults.standard.bool(forKey: Self.finaleKey(userId)))
    }

    private func finishOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.onboardedKey(userId))
        becomeReady(withFinale: true)
    }

    private func becomeReady(withFinale: Bool) {
        if withFinale {
            UserDefaults.standard.set(true, forKey: Self.finaleKey(userId))
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                homeSettled = false
                showsFinale = true
            }
        }
        stage = .ready
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
    @State private var creamOpacity: Double = 0
    /// Signed out: the mark turns white as it lands on the welcome screen's white mark.
    @State private var whiteOpacity: Double = 0
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
                    ZStack {
                        LogoMark(size: 96, trace: trace, fillOpacity: fill, ghost: ghost)
                        LogoMark(size: 96, style: .creamFill)
                            .opacity(creamOpacity)
                        BrandMark(size: 96)
                            .opacity(pngOpacity)
                    }
                    .opacity(1 - whiteOpacity)
                    LogoMark(size: 96, style: .white)
                        .opacity(whiteOpacity)
                }
                .overlay(alignment: .top) {
                    SplashWordmark(tracking: tracking, titleOpacity: titleOpacity, cityOpacity: cityOpacity)
                        .offset(y: 96 + 20)
                        .opacity(isHandingOff ? 0 : 1)
                }
                .scaleEffect(isHandingOff ? scale : 1)
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
        case .signedOut: .welcome
        case .loading: nil
        }
        let frame = key.flatMap { handoff.frames[$0] }
        var duration = Motion.splashHandoff

        if calm || frame == nil {
            withAnimation(.easeInOut(duration: Motion.splashHandoff)) {
                backgroundOpacity = 0
                logoOpacity = 0
            }
        } else if key == .welcome {
            // Signed out: the logo glides and shrinks from the centre to the top mark,
            // turning white as the cream lifts away to reveal the video.
            target = frame
            duration = Motion.splashWelcomeHandoff
            withAnimation(.easeInOut(duration: duration)) {
                isHandingOff = true
                backgroundOpacity = 0
                trace = 1
                fill = 1
                whiteOpacity = 1
            }
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
        try? await Task.sleep(for: .seconds(duration))
        onFinish()
    }
}

#Preview {
    ContentView()
}
