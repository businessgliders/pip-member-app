import SwiftUI

/// G. The welcome finale over Home: ink, a cream "( )" opening from the centre, then
/// "Pretty. Powerful. Pilates." word by word. After a hold, it scales up and fades away
/// while Home settles in underneath (`onExit` starts that). Reduce Motion: cross-fades only.
struct FinaleView: View {
    /// Called as the overlay starts to leave, so Home can scale in and un-blur in step.
    let onExit: () -> Void
    let onFinish: () -> Void

    @Environment(\.calmMotion) private var calm
    @State private var isOpen = false
    @State private var visibleWords = 0
    @State private var isLeaving = false
    @State private var lineWidth: CGFloat = 0
    @State private var haptic = 0

    private static let words = ["Pretty.", "Powerful.", "Pilates."]

    var body: some View {
        ZStack {
            Theme.fixedInk.ignoresSafeArea()

            ZStack {
                HStack(spacing: 7) {
                    ForEach(Self.words.indices, id: \.self) { index in
                        Text(Self.words[index])
                            .opacity(index < visibleWords ? 1 : 0)
                    }
                }
                .font(Typo.font(22, .light, relativeTo: .title2))
                .foregroundStyle(Theme.cream)
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { lineWidth = $0 }

                bracket("(")
                    .offset(x: isOpen ? -(lineWidth / 2 + 22) : -5)
                bracket(")")
                    .offset(x: isOpen ? lineWidth / 2 + 22 : 5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pretty. Powerful. Pilates.")
        }
        .scaleEffect(isLeaving && !calm ? 1.15 : 1)
        .opacity(isLeaving ? 0 : 1)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: haptic)
        .task { await play() }
    }

    private func bracket(_ glyph: String) -> some View {
        Text(glyph)
            .font(Typo.font(54, .light, relativeTo: .largeTitle))
            .foregroundStyle(Theme.cream)
            .opacity(isOpen || calm ? 1 : 0.4)
            .offset(y: -3)
    }

    private func play() async {
        if calm {
            isOpen = true
            withAnimation(Motion.fade) { visibleWords = Self.words.count }
            haptic += 1
            try? await Task.sleep(for: .seconds(Motion.short + Motion.finaleHold))
            onExit()
            withAnimation(.easeInOut(duration: Motion.finaleExit)) { isLeaving = true }
            try? await Task.sleep(for: .seconds(Motion.finaleExit))
            onFinish()
            return
        }

        try? await Task.sleep(for: .seconds(0.15))
        haptic += 1
        withAnimation(.easeInOut(duration: Motion.finaleOpen)) { isOpen = true }
        try? await Task.sleep(for: .seconds(Motion.finaleOpen))
        for index in 1...Self.words.count {
            withAnimation(.easeInOut(duration: Motion.finaleWordFade)) { visibleWords = index }
            if index < Self.words.count {
                try? await Task.sleep(for: .seconds(Motion.finaleWordStagger))
            }
        }
        try? await Task.sleep(for: .seconds(Motion.finaleWordFade + Motion.finaleHold))
        onExit()
        withAnimation(.easeInOut(duration: Motion.finaleExit)) { isLeaving = true }
        try? await Task.sleep(for: .seconds(Motion.finaleExit))
        onFinish()
    }
}
