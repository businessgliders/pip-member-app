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
            ScreenBackground()
            VStack(spacing: 20) {
                BrandMark(size: 112)
                    .shadow(color: Theme.pink.opacity(0.28), radius: 24, x: 0, y: 10)
                VStack(spacing: 6) {
                    Text("Pilates in Pink™")
                        .font(.title2.weight(.heavy))
                        .tracking(-0.4)
                        .foregroundStyle(Theme.ink)
                    Text("STUDIO")
                        .font(.footnote.weight(.bold))
                        .tracking(7)
                        .foregroundStyle(Theme.caramel)
                        .offset(x: 3.5) // optically recenter letterspaced caps
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
