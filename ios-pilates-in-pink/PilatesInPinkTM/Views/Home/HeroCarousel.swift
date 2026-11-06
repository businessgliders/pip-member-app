import SwiftUI

struct HeroSlide: Identifiable {
    enum Action { case classes(ClassFamily?), me }
    let id: Int
    let image: String
    let headline: String
    let subtitle: String
    let button: String
    let action: Action

    static let all: [HeroSlide] = [
        HeroSlide(id: 0, image: "hero_1", headline: "Welcome to\nPilates in Pink™",
                  subtitle: "Brampton's reformer studio — book in seconds.", button: "Book a class", action: .classes(nil)),
        HeroSlide(id: 1, image: "hero_2", headline: "Find your reformer",
                  subtitle: "Choose your exact spot in the room.", button: "See the schedule", action: .classes(nil)),
        HeroSlide(id: 2, image: "hero_3", headline: "New to reformer?",
                  subtitle: "Start with an Intro Class. We'll guide every move.", button: "Intro classes", action: .classes(.intro)),
        HeroSlide(id: 3, image: "hero_4", headline: "Bring a friend",
                  subtitle: "Everything's better together. Guest passes live in your profile.", button: "Learn more", action: .me),
        HeroSlide(id: 4, image: "hero_5", headline: "Core in Blush",
                  subtitle: "Our signature core class, all week long.", button: "Find a class", action: .classes(.core))
    ]
}

/// Full-bleed photo carousel with page dots; auto-advances gently.
/// On the iPhone Duo inner display (`fold` set), the photo sits in the left pane and the words
/// in the right, so neither the photo's subject nor any text lands on the fold.
struct HeroCarousel: View {
    var fold: ClosedRange<CGFloat>? = nil
    let onAction: (HeroSlide.Action) -> Void
    @State private var index = 0
    @State private var lastInteraction = Date()
    private let slides = HeroSlide.all

    var body: some View {
        TabView(selection: $index) {
            ForEach(slides) { slide in
                slideView(slide).tag(slide.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: fold == nil ? .bottom : .bottomTrailing) {
            dots
                .padding(.bottom, Theme.sheetRadius + 14)
                .padding(.trailing, fold == nil ? 0 : 24)
        }
        .onChange(of: index) { _, _ in lastInteraction = Date() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(7))
                if Date().timeIntervalSince(lastInteraction) >= 6.5 {
                    withAnimation(.easeInOut(duration: 0.8)) { index = (index + 1) % slides.count }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: index)
    }

    @ViewBuilder
    private func slideView(_ slide: HeroSlide) -> some View {
        if let fold {
            ZStack(alignment: .topLeading) {
                StudioPhoto(name: slide.image, tone: .deep)
                    .blur(radius: 28)
                    .overlay(Color.black.opacity(0.42))
                HStack(spacing: 0) {
                    StudioPhoto(name: slide.image, tone: .deep, fadeIn: true)
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
                StudioPhoto(name: slide.image, tone: .deep, fadeIn: true)
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
            Text(slide.subtitle)
                .font(Typo.font(16, .regular, relativeTo: .body))
                .foregroundStyle(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
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
        .animation(Theme.spring, value: index)
        .accessibilityElement()
        .accessibilityLabel("Slide \(index + 1) of \(slides.count)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: index = min(slides.count - 1, index + 1)
            case .decrement: index = max(0, index - 1)
            @unknown default: break
            }
        }
    }
}
