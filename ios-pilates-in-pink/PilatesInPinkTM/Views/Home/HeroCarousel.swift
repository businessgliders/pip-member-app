import SwiftUI

struct HeroSlide: Identifiable, Equatable {
    typealias Action = HomeBanner.Action
    let id: String
    /// Bundled photo: used when there's no `imageURL`, or it fails to load.
    let image: String
    let imageURL: URL?
    /// The subject of the photo (0–1 in the photo): kept in frame however the hero is shaped.
    let focus: UnitPoint
    let headline: String
    let subtitle: String
    /// Nil hides the button.
    let button: String?
    let action: Action

    /// Where the subject sits in each bundled hero photo (faces, the neon logo).
    static let focusPoints: [String: UnitPoint] = [
        "hero_1": UnitPoint(x: 0.5, y: 0.42),  // Neon "P" on the pink wall.
        "hero_2": UnitPoint(x: 0.5, y: 0.5),   // Arched room: instructor and client.
        "hero_3": UnitPoint(x: 0.5, y: 0.3),   // Instructor's face and the neon logo.
        "hero_4": UnitPoint(x: 0.35, y: 0.52), // Three faces down the left side.
        "hero_5": UnitPoint(x: 0.5, y: 0.42)   // "Core on fire, Confidence Higher".
    ]
    static let defaultFocus = UnitPoint(x: 0.5, y: 0.4)

    init(id: String, image: String, imageURL: URL? = nil, headline: String, subtitle: String, button: String?, action: Action) {
        self.id = id
        self.image = image
        self.imageURL = imageURL
        self.focus = Self.focusPoints[image] ?? Self.defaultFocus
        self.headline = headline
        self.subtitle = subtitle
        self.action = action
        if case .none = action { self.button = nil } else { self.button = button }
    }

    init(banner: HomeBanner) {
        self.init(
            id: banner.id,
            image: banner.fallbackAsset?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            imageURL: banner.imageURL,
            headline: banner.headline ?? "",
            subtitle: banner.subtitle ?? "",
            button: banner.trimmedButtonLabel,
            action: banner.action
        )
    }

    /// Shown only on the very first launch, before the studio's banners have ever loaded.
    static let firstRun: [HeroSlide] = [
        HeroSlide(id: "local-1", image: "hero_1", headline: "Welcome to\nPilates in Pink™",
                  subtitle: "Brampton's reformer studio — book in seconds.", button: "Book a class", action: .classes(nil))
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
    let slides: [HeroSlide]
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

    private var isSingle: Bool { slides.count <= 1 }

    var body: some View {
        ZStack {
            ForEach(Array(slides.enumerated()), id: \.element.id) { position, slide in
                if position == index || position == outgoing {
                    let isCurrent = position == index
                    slideView(slide, at: position)
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
        .simultaneousGesture(swipe, isEnabled: !isSingle)
        .overlay(alignment: fold == nil ? .bottom : .bottomTrailing) {
            if !isSingle {
                dots
                    .padding(.bottom, Theme.sheetRadius + 14)
                    .padding(.trailing, fold == nil ? 0 : 24)
            }
        }
        .onAppear { textIndex = index }
        .onChange(of: slides.map(\.id)) { _, ids in
            // The studio changed its banners: stay in range.
            if index >= ids.count {
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) {
                    outgoing = nil
                    index = 0
                    textIndex = 0
                }
            }
        }
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
                // One banner: no auto-advance.
                guard slides.count > 1, !isTouching, !isScrolling,
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
                guard slides.count > 1, abs(dx) > 50, abs(dx) > abs(dy) * 1.5 else { return }
                swipes += 1
                show(dx < 0 ? (index + 1) % slides.count : (index - 1 + slides.count) % slides.count)
            }
    }

    /// Slow push-in on the showing photo (off when motion is calm).
    private func zoomed(_ position: Int) -> CGFloat {
        calm ? 1 : (position == index && isZooming ? 1.05 : 1)
    }

    private func photo(_ slide: HeroSlide, fadeIn: Bool = false) -> StudioPhoto {
        StudioPhoto(name: slide.image, focus: slide.focus, tone: .deep, fadeIn: fadeIn, remoteURL: slide.imageURL)
    }

    @ViewBuilder
    private func slideView(_ slide: HeroSlide, at position: Int) -> some View {
        if let fold {
            ZStack(alignment: .topLeading) {
                photo(slide)
                    .blur(radius: 28)
                    .overlay(Color.black.opacity(0.42))
                HStack(spacing: 0) {
                    photo(slide, fadeIn: true)
                        .scaleEffect(zoomed(position), anchor: UnitPoint(x: slide.focus.x, y: slide.focus.y))
                        .animation(.easeInOut(duration: Motion.heroPushInDuration), value: index)
                        .animation(.easeInOut(duration: Motion.heroPushInDuration), value: isZooming)
                        .frame(width: fold.lowerBound)
                        .overlay {
                            LinearGradient(colors: [Color.black.opacity(0.3), .clear], startPoint: .top, endPoint: .center)
                        }
                        .clipped()
                    Color.clear.frame(width: fold.upperBound - fold.lowerBound)
                    slideText(slide, at: position)
                        .padding(.leading, 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            }
            .clipped()
        } else {
            ZStack(alignment: .bottomLeading) {
                photo(slide, fadeIn: true)
                    .scaleEffect(zoomed(position))
                    .clipped()
                    .animation(.easeInOut(duration: Motion.heroPushInDuration), value: index)
                    .animation(.easeInOut(duration: Motion.heroPushInDuration), value: isZooming)
                LinearGradient(
                    colors: [Color.black.opacity(0.35), .clear, Color.black.opacity(0.15), Color.black.opacity(0.62)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                slideText(slide, at: position)
                    .frame(maxWidth: 560, alignment: .leading)
            }
            .clipped()
        }
    }

    private func slideText(_ slide: HeroSlide, at position: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !slide.headline.isEmpty {
                Text(slide.headline)
                    .font(Typo.font(38, .light, relativeTo: .largeTitle))
                    .tracking(-0.6)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .riseIn(textIndex == position)
            }
            if !slide.subtitle.isEmpty {
                Text(slide.subtitle)
                    .font(Typo.font(16, .regular, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
                    .riseIn(textIndex == position)
            }
            if let button = slide.button {
                Button { onAction(slide.action) } label: {
                    HStack(spacing: 8) {
                        Text(button.uppercased())
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
        }
        .padding(.horizontal, 24)
        .padding(.bottom, Theme.sheetRadius + 44)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { position in
                Capsule()
                    .fill(Color.white.opacity(position == index ? 0.95 : 0.45))
                    .frame(width: position == index ? 18 : 6, height: 6)
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
