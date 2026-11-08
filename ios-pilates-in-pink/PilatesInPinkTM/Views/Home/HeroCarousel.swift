import SwiftUI

struct HeroSlide: Identifiable {
    enum Action { case classes(ClassFamily?), me }
    let id: Int
    let image: String
    /// The subject of the photo (0–1 in the photo): kept in frame however the hero is shaped.
    let focus: UnitPoint
    let headline: String
    let subtitle: String
    let button: String
    let action: Action

    static let all: [HeroSlide] = [
        // Neon "P" on the pink wall.
        HeroSlide(id: 0, image: "hero_1", focus: UnitPoint(x: 0.5, y: 0.42), headline: "Welcome to\nPilates in Pink™",
                  subtitle: "Brampton's reformer studio — book in seconds.", button: "Book a class", action: .classes(nil)),
        // Arched room: instructor and client.
        HeroSlide(id: 1, image: "hero_2", focus: UnitPoint(x: 0.5, y: 0.5), headline: "Find your reformer",
                  subtitle: "Choose your exact spot in the room.", button: "See the schedule", action: .classes(nil)),
        // Instructor's face and the neon logo.
        HeroSlide(id: 2, image: "hero_3", focus: UnitPoint(x: 0.5, y: 0.3), headline: "New to reformer?",
                  subtitle: "Start with an Intro Class. We'll guide every move.", button: "Intro classes", action: .classes(.intro)),
        // Three faces down the left side.
        HeroSlide(id: 3, image: "hero_4", focus: UnitPoint(x: 0.35, y: 0.52), headline: "Bring a friend",
                  subtitle: "Everything's better together. Guest passes live in your profile.", button: "Learn more", action: .me),
        // "Core on fire, Confidence Higher".
        HeroSlide(id: 4, image: "hero_5", focus: UnitPoint(x: 0.5, y: 0.42), headline: "Core in Blush",
                  subtitle: "Our signature core class, all week long.", button: "Find a class", action: .classes(.core))
    ]
}

/// Full-bleed photo carousel with page dots. Slides cross-fade every 6s (paused while the member is
/// touching or scrolling), each photo slowly pushes in, and the words rise in just after the photo.
/// A horizontal swipe changes slide with the same cross-fade.
/// On the iPhone Duo inner display (`fold` set), the photo sits in the left pane and the words
/// in the right, so neither the photo's subject nor any text lands on the fold.
struct HeroCarousel: View {
    var fold: ClosedRange<CGFloat>? = nil
    /// The page around the carousel is scrolling: hold the current slide.
    var isScrolling: Bool = false
    let onAction: (HeroSlide.Action) -> Void

    @Environment(\.calmMotion) private var calm
    @State private var index = 0
    /// Which slide's words are showing; follows `index` after a short beat.
    @State private var textIndex = 0
    @State private var isZooming = false
    @State private var isTouching = false
    @State private var lastChange = Date()
    @State private var swipes = 0
    /// The slide fading out during a cross-fade; only it and the current slide are drawn.
    @State private var outgoing: Int?
    private let slides = HeroSlide.all

    var body: some View {
        ZStack {
            ForEach(slides) { slide in
                if slide.id == index || slide.id == outgoing {
                    let isCurrent = slide.id == index
                    slideView(slide)
                        .opacity(isCurrent ? 1 : 0)
                        .allowsHitTesting(isCurrent)
                        .accessibilityHidden(!isCurrent)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Touches (and the swipe) stay inside the hero's own frame.
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(swipe)
        .overlay(alignment: fold == nil ? .bottom : .bottomTrailing) {
            dots
                .padding(.bottom, Theme.sheetRadius + 14)
                .padding(.trailing, fold == nil ? 0 : 24)
        }
        .onAppear { textIndex = index }
        .onDisappear {
            // Stop the push-in where it is; it restarts after the next appearance settles.
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { isZooming = false }
        }
        .onChange(of: index) { oldValue, newValue in
            lastChange = Date()
            outgoing = oldValue
            Task {
                try? await Task.sleep(for: .seconds(Motion.heroTextDelay))
                withAnimation(Motion.choose(Motion.easeLong, calm: calm)) { textIndex = newValue }
                try? await Task.sleep(for: .seconds(Motion.longest))
                if outgoing == oldValue { outgoing = nil }
            }
        }
        .onChange(of: isScrolling) { _, _ in lastChange = Date() }
        // Push-in and auto-advance wait until the tab switch has settled; SwiftUI cancels
        // this task when Home disappears.
        .task {
            try? await Task.sleep(for: .seconds(Motion.heroStartDelay))
            guard !Task.isCancelled else { return }
            isZooming = true
            lastChange = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.5))
                guard !Task.isCancelled else { break }
                guard !isTouching, !isScrolling,
                      Date().timeIntervalSince(lastChange) >= Motion.heroSlideInterval else { continue }
                show((index + 1) % slides.count)
            }
        }
        .sensoryFeedback(.selection, trigger: swipes)
    }

    private func show(_ newIndex: Int) {
        withAnimation(Motion.choose(Motion.heroSlideChange, calm: calm)) { index = newIndex }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { _ in if !isTouching { isTouching = true } }
            .onEnded { value in
                isTouching = false
                lastChange = Date()
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                swipes += 1
                show(dx < 0 ? (index + 1) % slides.count : (index - 1 + slides.count) % slides.count)
            }
    }

    /// Slow push-in on the showing photo (off when motion is calm).
    private func zoomed(_ slide: HeroSlide) -> CGFloat {
        calm ? 1 : (slide.id == index && isZooming ? 1.05 : 1)
    }

    @ViewBuilder
    private func slideView(_ slide: HeroSlide) -> some View {
        if let fold {
            ZStack(alignment: .topLeading) {
                StudioPhoto(name: slide.image, focus: slide.focus, tone: .deep)
                    .blur(radius: 28)
                    .overlay(Color.black.opacity(0.42))
                HStack(spacing: 0) {
                    StudioPhoto(name: slide.image, focus: slide.focus, tone: .deep, fadeIn: true)
                        .scaleEffect(zoomed(slide), anchor: UnitPoint(x: slide.focus.x, y: slide.focus.y))
                        .animation(.easeInOut(duration: Motion.heroPushInDuration), value: index)
                        .animation(.easeInOut(duration: Motion.heroPushInDuration), value: isZooming)
                        .frame(width: fold.lowerBound)
                        .overlay {
                            LinearGradient(colors: [Color.black.opacity(0.3), .clear], startPoint: .top, endPoint: .center)
                        }
                        .clipped()
                    Color.clear.frame(width: fold.upperBound - fold.lowerBound)
                    slideText(slide)
                        .padding(.leading, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .clipped()
        } else {
            ZStack(alignment: .bottomLeading) {
                StudioPhoto(name: slide.image, focus: slide.focus, tone: .deep, fadeIn: true)
                    .scaleEffect(zoomed(slide))
                    .clipped()
                    .animation(.easeInOut(duration: Motion.heroPushInDuration), value: index)
                    .animation(.easeInOut(duration: Motion.heroPushInDuration), value: isZooming)
                LinearGradient(
                    colors: [Color.black.opacity(0.35), .clear, Color.black.opacity(0.15), Color.black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                slideText(slide)
                    .frame(maxWidth: 560, alignment: .leading)
            }
            .clipped()
        }
    }

    private func slideText(_ slide: HeroSlide) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(slide.headline)
                .font(Typo.font(38, .light, relativeTo: .largeTitle))
                .tracking(-0.6)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .riseIn(textIndex == slide.id)
            Text(slide.subtitle)
                .font(Typo.font(16, .regular, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .riseIn(textIndex == slide.id)
            Button { onAction(slide.action) } label: {
                HStack(spacing: 8) {
                    Text(slide.button.uppercased())
                        .font(Typo.font(12, .medium, relativeTo: .caption))
                        .tracking(1.6)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 44)
                .contentShape(Capsule())
            }
            .buttonStyle(PressableCardStyle())
            .glass(Capsule(), dark: true, interactive: true)
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, Theme.sheetRadius + 44)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(slides) { slide in
                Capsule()
                    .fill(Color.white.opacity(slide.id == index ? 0.95 : 0.45))
                    .frame(width: slide.id == index ? 18 : 6, height: 6)
            }
        }
        .animation(Motion.choose(Motion.spring, calm: calm), value: index)
        .accessibilityElement()
        .accessibilityLabel("Slide \(index + 1) of \(slides.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: show(min(slides.count - 1, index + 1))
            case .decrement: show(max(0, index - 1))
            @unknown default: break
            }
        }
    }
}
