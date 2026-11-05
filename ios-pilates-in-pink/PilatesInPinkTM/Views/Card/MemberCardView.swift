import SwiftUI
import UIKit

/// Member card with an on-device QR code (display only). Fixed colours, like a physical card.
struct MemberCardView: View {
    private enum Segment: String, CaseIterable { case card = "Member Card", guests = "Guest Passes" }

    @Environment(AuthStore.self) private var auth
    @Environment(StudioStore.self) private var store
    @State private var segment: Segment = .card
    @State private var hasAppeared = false
    @Namespace private var segmentNS

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenTitle(text: segment.rawValue)
                    .contentTransition(.opacity)
                    .padding(.top, 12)

                segmentPicker

                if segment == .card {
                    card
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    Text("Show this at the front desk when you arrive.")
                        .font(Typo.secondary)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                } else {
                    guestPasses
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .readableWidth(520)
            .animation(Theme.spring, value: segment)
        }
        .scrollIndicators(.hidden)
        .floatingNavClearance()
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: segment)
        .task { if !store.hasLoadedCredits { await store.refreshCredits() } }
    }

    private var segmentPicker: some View {
        HStack(spacing: 4) {
            ForEach(Segment.allCases, id: \.self) { item in
                Button {
                    withAnimation(Theme.spring) { segment = item }
                } label: {
                    Text(item.rawValue.uppercased())
                        .font(Typo.font(12, .medium, relativeTo: .caption))
                        .tracking(1.4)
                        .foregroundStyle(segment == item ? Theme.ink : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if segment == item {
                                Capsule().fill(Theme.card)
                                    .matchedGeometryEffect(id: "seg", in: segmentNS)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(segment == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.blush, in: Capsule())
    }

    private var card: some View {
        VStack(spacing: 0) {
            HStack {
                Wordmark(color: Theme.cream, markSize: 28, textSize: 18)
                Spacer()
                Text("BRAMPTON")
                    .font(Typo.font(11, .medium, relativeTo: .caption2))
                    .tracking(1.8)
                    .foregroundStyle(Theme.cream.opacity(0.7))
            }
            .padding(.horizontal, 22)
            .frame(height: 76)
            .background(Theme.fixedInk)

            VStack(spacing: 22) {
                qr
                    .padding(.top, 26)
                VStack(spacing: 8) {
                    Text(auth.firstName.isEmpty ? auth.displayName : auth.firstName)
                        .font(Typo.font(28, .light, relativeTo: .title))
                        .foregroundStyle(Theme.fixedInk)
                    Text(store.credits?.memberLabel ?? (store.hasLoadedCredits ? "NO ACTIVE MEMBERSHIP" : " "))
                        .font(Typo.font(12, .medium, relativeTo: .caption))
                        .tracking(1.8)
                        .foregroundStyle(Color(hex: 0xB67651))
                }
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity)
            .background(Theme.cream)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
        .environment(\.colorScheme, .light)
        .scaleEffect(hasAppeared ? 1 : 0.97)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear { withAnimation(Theme.softSpring) { hasAppeared = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Member card for \(auth.displayName)")
    }

    @ViewBuilder
    private var qr: some View {
        if let id = auth.userId?.uuidString,
           let image = QRCode.image(for: id, foreground: UIColor(hex: 0x1A1418), background: UIColor(hex: 0xF6EEE7)) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .accessibilityLabel("Member QR code")
        } else {
            SkeletonBlock(width: 200, height: 200, radius: 12)
        }
    }

    @ViewBuilder
    private var guestPasses: some View {
        let count = store.credits?.guestPassCount ?? 0
        if count > 0 {
            VStack(alignment: .leading, spacing: 10) {
                EyebrowText("Available")
                Text(count == 1 ? "1 guest pass" : "\(count) guest passes")
                    .font(Typo.font(30, .light, relativeTo: .title))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text("Bring a friend to class — guest booking in the app is coming soon. Let the front desk know when you arrive.")
                    .font(Typo.secondary)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .cardStyle(padding: 22)
        } else {
            EmptyStateCard(
                systemImage: "person.2",
                title: "No guest passes",
                message: "You don't have any guest passes yet."
            )
        }
    }
}
