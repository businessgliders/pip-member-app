import SwiftUI

/// The studio logo mark — the pink "P" from the app icon artwork.
/// Static uses keep the original PNG artwork; anything that animates uses `LogoMark` (vector).
struct BrandMark: View {
    var size: CGFloat

    var body: some View {
        Image("AppLogo")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Mark + "Pilates in Pink™" wordmark.
struct Wordmark: View {
    var color: Color = Theme.ink
    var markSize: CGFloat = 30
    var textSize: CGFloat = 17
    /// Cream vector mark (for the ink band on the member card).
    var creamMark: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            if creamMark {
                LogoMark(size: markSize, style: .cream)
            } else {
                BrandMark(size: markSize)
            }
            Text("Pilates in Pink™")
                .font(Typo.font(textSize, .light, relativeTo: .headline))
                .tracking(0.6)
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pilates in Pink")
    }
}

// MARK: - Vector logo

/// Geometry measured from the 768-unit logo artwork: a shared vertical stem, a half-disc on the
/// upper right and a half-disc on the lower left. Scaled uniformly and centred in the rect,
/// so a `LogoMark` overlays the PNG exactly.
enum LogoGeometry {
    static let canvas: CGFloat = 768
    static let stemX: CGFloat = 390
    static let stemTop: CGFloat = 32
    static let stemBottom: CGFloat = 736
    /// Upper-right half-disc.
    static let topCenter = CGPoint(x: 390, y: 266)
    static let topRadii = CGSize(width: 246, height: 234)
    /// Lower-left half-disc.
    static let bottomCenter = CGPoint(x: 390, y: 500)
    static let bottomRadii = CGSize(width: 247, height: 236)
    /// Outline weight relative to the mark's size.
    static let strokeRatio: CGFloat = 0.035
}

struct LogoPart: Shape {
    enum Kind {
        case topFill, bottomFill
        /// Arcs drawn from their outer extreme toward the stem, so a trim "draws toward the stem".
        case topArcUp, topArcDown, bottomArcUp, bottomArcDown
        case topStem, bottomStem
    }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        let g = LogoGeometry.self
        let s = min(rect.width, rect.height) / g.canvas
        let ox = rect.midX - g.canvas * s / 2
        let oy = rect.midY - g.canvas * s / 2
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }

        func arc(center: CGPoint, radii: CGSize, start: Double, delta: Double, closed: Bool = false) -> Path {
            var unit = Path()
            unit.addRelativeArc(center: .zero, radius: 1, startAngle: .degrees(start), delta: .degrees(delta))
            if closed { unit.closeSubpath() }
            let transform = CGAffineTransform(translationX: ox + center.x * s, y: oy + center.y * s)
                .scaledBy(x: radii.width * s, y: radii.height * s)
            return unit.applying(transform)
        }

        switch kind {
        case .topFill:
            return arc(center: g.topCenter, radii: g.topRadii, start: -90, delta: 180, closed: true)
        case .bottomFill:
            return arc(center: g.bottomCenter, radii: g.bottomRadii, start: 90, delta: 180, closed: true)
        case .topArcUp:
            return arc(center: g.topCenter, radii: g.topRadii, start: 0, delta: -90)
        case .topArcDown:
            return arc(center: g.topCenter, radii: g.topRadii, start: 0, delta: 90)
        case .bottomArcUp:
            return arc(center: g.bottomCenter, radii: g.bottomRadii, start: 180, delta: 90)
        case .bottomArcDown:
            return arc(center: g.bottomCenter, radii: g.bottomRadii, start: 180, delta: -90)
        case .topStem:
            var p = Path()
            p.move(to: pt(g.stemX, g.topCenter.y + g.topRadii.height))
            p.addLine(to: pt(g.stemX, g.stemTop))
            return p
        case .bottomStem:
            var p = Path()
            p.move(to: pt(g.stemX, g.bottomCenter.y - g.bottomRadii.height))
            p.addLine(to: pt(g.stemX, g.stemBottom))
            return p
        }
    }
}

/// Vector logo. `trace` draws the outline (0…1), `separation` pulls the halves apart sideways,
/// `ghost` shows a faint full outline underneath the trace.
struct LogoMark: View {
    enum Style {
        /// Pink outline, blush fill — the artwork.
        case brand
        /// Pink outline, cream fill — on glass over photos.
        case creamFill
        /// Cream outline, faint cream fill — on the ink band.
        case cream
        /// Soft pink outline, blush fill — empty states (drawn at reduced opacity).
        case quiet
    }

    var size: CGFloat
    var style: Style = .brand
    var trace: CGFloat = 1
    var fillOpacity: Double = 1
    var separation: CGFloat = 0
    var ghost: Double = 0

    private var outline: Color {
        switch style {
        case .brand, .creamFill: Theme.pink
        case .cream: Theme.cream
        case .quiet: Theme.softPink
        }
    }

    private var fill: Color {
        switch style {
        case .brand: Color(hex: 0xFBE0E2)
        case .creamFill: Theme.cream
        case .cream: Theme.cream.opacity(0.16)
        case .quiet: Theme.blush
        }
    }

    var body: some View {
        let lineWidth = max(1, size * LogoGeometry.strokeRatio)
        let stroke = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        ZStack {
            half(fill: .topFill, parts: [.topArcUp, .topArcDown, .topStem], stroke: stroke)
                .offset(x: separation)
            half(fill: .bottomFill, parts: [.bottomArcUp, .bottomArcDown, .bottomStem], stroke: stroke)
                .offset(x: -separation)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func half(fill kind: LogoPart.Kind, parts: [LogoPart.Kind], stroke: StrokeStyle) -> some View {
        ZStack {
            LogoPart(kind: kind).fill(fill).opacity(fillOpacity)
            if ghost > 0 {
                ForEach(parts.indices, id: \.self) { i in
                    LogoPart(kind: parts[i]).stroke(outline.opacity(ghost), style: stroke)
                }
            }
            ForEach(parts.indices, id: \.self) { i in
                LogoPart(kind: parts[i])
                    .trim(from: 0, to: trace)
                    .stroke(outline, style: stroke)
            }
        }
    }
}

/// The outline tracing itself in a loop (1.2s, easeInOut). When `isActive` turns off the
/// current stroke finishes smoothly instead of stopping mid-line.
struct LogoTraceIndicator: View {
    var size: CGFloat = 26
    var isActive: Bool
    /// Pull distance before refresh starts (0…1) — draws the outline with the finger.
    var pullProgress: CGFloat = 0
    @Environment(\.calmMotion) private var calm
    @State private var progress: CGFloat = 0
    @State private var isLooping = false

    var body: some View {
        LogoMark(
            size: size,
            trace: calm ? 1 : (isLooping || isActive ? progress : pullProgress),
            fillOpacity: 0.9,
            ghost: 0.22
        )
        .task(id: isActive) {
            guard isActive else {
                withAnimation(Motion.fade) { progress = 1 }
                try? await Task.sleep(for: .seconds(Motion.short))
                isLooping = false
                return
            }
            isLooping = true
            var start = Transaction()
            start.disablesAnimations = true
            withTransaction(start) { progress = min(pullProgress, 1) }
            while !Task.isCancelled && !calm {
                withAnimation(Motion.refreshTraceAnimation) { progress = 1 }
                try? await Task.sleep(for: .seconds(Motion.refreshTrace + 0.15))
                guard !Task.isCancelled else { break }
                withTransaction(start) { progress = 0 }
            }
        }
    }
}

// MARK: - Pull to refresh with the logo

/// Replaces the system spinner: pulling past the threshold draws the logo, releasing starts
/// `action` with the outline tracing in a loop until it finishes. The indicator floats in a small
/// glass circle and never moves the content or blocks a tap.
struct LogoRefreshModifier: ViewModifier {
    var topPadding: CGFloat = 8
    let action: () async -> Void

    @Environment(\.calmMotion) private var calm
    @State private var pull: CGFloat = 0
    @State private var isInteracting = false
    @State private var isArmed = false
    @State private var isRefreshing = false
    @State private var isShowing = false

    private let threshold: CGFloat = 80

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                -(geo.contentOffset.y + geo.contentInsets.top)
            } action: { _, value in
                pull = max(0, value)
                if isInteracting && !isRefreshing { isArmed = pull >= threshold }
            }
            .onScrollPhaseChange { _, phase in
                let wasInteracting = isInteracting
                isInteracting = phase == .interacting
                if wasInteracting && !isInteracting && isArmed && !isRefreshing {
                    isArmed = false
                    start()
                }
            }
            .overlay(alignment: .top) {
                indicator
                    .padding(.top, topPadding)
                    .allowsHitTesting(false)
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: isArmed) { _, armed in armed }
            .accessibilityAction(named: "Refresh") { start() }
    }

    private var pullProgress: CGFloat { min(1, pull / threshold) }

    private var indicator: some View {
        LogoTraceIndicator(size: 24, isActive: isRefreshing, pullProgress: pullProgress)
            .frame(width: 44, height: 44)
            .glass(Circle())
            .opacity(isShowing ? 1 : (isRefreshing ? 1 : Double(min(1, max(0, (pull - 16) / 48)))))
            .offset(y: isShowing || calm ? 0 : -Motion.rise * (1 - pullProgress))
            .accessibilityHidden(true)
    }

    private func start() {
        guard !isRefreshing else { return }
        withAnimation(Motion.fade) {
            isRefreshing = true
            isShowing = true
        }
        Task {
            await action()
            // Let the current stroke finish, then fade away.
            isRefreshing = false
            try? await Task.sleep(for: .seconds(Motion.short + 0.1))
            withAnimation(Motion.ease) { isShowing = false }
        }
    }
}

extension View {
    /// Pull to refresh with the logo outline instead of the system spinner. Apply to a ScrollView.
    func logoRefreshable(topPadding: CGFloat = 8, action: @escaping () async -> Void) -> some View {
        modifier(LogoRefreshModifier(topPadding: topPadding, action: action))
    }
}

// MARK: - Splash hand-off targets

/// Where the splash logo should land: the sign-in mark or the Home header mark.
/// Targets report their on-screen frame and stay invisible until the splash has handed off.
@Observable
final class LogoHandoff {
    enum Target: Hashable { case signIn, home }
    var frames: [Target: CGRect] = [:]
    /// True while the cold-launch splash is on screen; target marks wait underneath it.
    var isSplashActive: Bool = true
}

struct LogoHandoffTarget: ViewModifier {
    let target: LogoHandoff.Target
    @Environment(LogoHandoff.self) private var handoff

    func body(content: Content) -> some View {
        content
            .opacity(handoff.isSplashActive ? 0 : 1)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                // Only needed for the cold-launch hand-off; stop tracking once it's done.
                guard handoff.isSplashActive else { return }
                handoff.frames[target] = frame
            }
    }
}

extension View {
    func logoHandoffTarget(_ target: LogoHandoff.Target) -> some View {
        modifier(LogoHandoffTarget(target: target))
    }
}
