import SwiftUI

/// Root: switches between signed-out and signed-in purely from auth state changes.
struct ContentView: View {
    @State private var auth = AuthStore()

    var body: some View {
        ZStack {
            switch auth.phase {
            case .loading:
                SplashView()
                    .transition(.opacity)
            case .signedOut:
                WelcomeView()
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
                    .id(auth.userId)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.phase)
        .environment(auth)
        .tint(Theme.ink)
    }
}

struct SplashView: View {
    @State private var hasAppeared: Bool = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                BrandMark(size: 96)
                VStack(spacing: 8) {
                    Text("Pilates in Pink™")
                        .font(Typo.font(26, .light, relativeTo: .title))
                        .foregroundStyle(Theme.ink)
                    Text("BRAMPTON")
                        .font(Typo.font(11, .medium, relativeTo: .caption2))
                        .tracking(3)
                        .foregroundStyle(Theme.secondaryText)
                        .offset(x: 1.5)
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.92)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { hasAppeared = true }
        }
    }
}

#Preview {
    ContentView()
}
