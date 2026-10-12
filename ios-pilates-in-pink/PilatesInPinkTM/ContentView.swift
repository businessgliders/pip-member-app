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
    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 14) {
                ReformerIcon()
                    .stroke(Theme.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 84, height: 42)
                Text("Pilates in Pink")
                    .font(.title3.weight(.heavy))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
            }
        }
    }
}

#Preview {
    ContentView()
}
