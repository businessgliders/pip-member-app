import SwiftUI
import UIKit

/// A studio photo from the asset catalog. Tries `name`, then each of `fallbacks`; if none
/// exists, draws a warm blush-to-cream gradient with soft grain so screens still feel finished.
/// `alignment` decides which part of an aspect-filled photo stays in view (`.top` keeps faces
/// and raised arms).
struct StudioPhoto: View {
    enum Tone { case light, deep }

    let name: String
    var fallbacks: [String] = []
    var alignment: Alignment = .center
    var tone: Tone = .light
    var fadeIn: Bool = false
    @State private var isVisible = false

    private var image: UIImage? {
        ([name] + fallbacks).lazy.compactMap { UIImage(named: $0) }.first
    }

    var body: some View {
        Color.clear
            .overlay(alignment: alignment) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    PlaceholderArt(seed: name, tone: tone)
                }
            }
            .clipped()
            .opacity(fadeIn ? (isVisible ? 1 : 0) : 1)
            .onAppear {
                guard fadeIn, !isVisible else { return }
                withAnimation(.easeInOut(duration: Motion.longest)) { isVisible = true }
            }
            .accessibilityHidden(true)
    }
}

private struct PlaceholderArt: View {
    let seed: String
    let tone: StudioPhoto.Tone

    private var hash: Int { seed.unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF } }

    private var colors: [Color] {
        switch tone {
        case .deep:
            let sets: [[UInt32]] = [
                [0xC98A78, 0xB06A6E, 0x4A3036],
                [0xD9A08A, 0xA8656C, 0x3E2A30],
                [0xE0B09C, 0xB67651, 0x45302E],
                [0xD6979D, 0x9C5E64, 0x35252B],
                [0xCFA08A, 0xA86F5E, 0x3C2B2C]
            ]
            return sets[hash % sets.count].map { Color(hex: $0) }
        case .light:
            let sets: [[UInt32]] = [
                [0xFBE0E2, 0xF6EEE7, 0xEFD3CC],
                [0xF7D5D6, 0xF8EEE6, 0xE9CDBE],
                [0xF9E6DF, 0xF3D6D8, 0xE8C9C3],
                [0xF6EEE7, 0xF7C9CF, 0xEAD2C4],
                [0xF8E2DC, 0xF6EEE7, 0xE4C2B8]
            ]
            return sets[hash % sets.count].map { Color(hex: $0) }
        }
    }

    var body: some View {
        let angle = Double(hash % 360)
        let glowX = 0.2 + Double(hash % 60) / 100
        ZStack {
            LinearGradient(
                colors: colors,
                startPoint: UnitPoint(x: 0.5 + 0.5 * cos(angle * .pi / 180), y: 0),
                endPoint: UnitPoint(x: 0.5 - 0.5 * cos(angle * .pi / 180), y: 1)
            )
            RadialGradient(
                colors: [Color.white.opacity(tone == .deep ? 0.28 : 0.55), .clear],
                center: UnitPoint(x: glowX, y: 0.25),
                startRadius: 0,
                endRadius: 320
            )
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
                .opacity(tone == .deep ? 0.07 : 0.10)
                .blendMode(.softLight)
                .offset(x: CGFloat(hash % 80) - 20, y: 30)
            Image("grain")
                .resizable(resizingMode: .tile)
                .opacity(tone == .deep ? 0.22 : 0.16)
                .blendMode(.overlay)
        }
    }
}
