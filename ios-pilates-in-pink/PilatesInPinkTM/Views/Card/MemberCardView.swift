import SwiftUI
import UIKit

/// Member card with an on-device QR code (display only). Fixed colours, like a physical card.
struct MemberCardView: View {
    private enum Segment: String, CaseIterable { case card = "Member Card", guests = "Guest Passes" }

    @Environment(AuthStore.self) private var auth
    @Environment(StudioStore.self) private var store
    @State private var segment: Segment = .card
    @State private var hasAppeared = false
    @Environment(\.calmMotion) private var calm
    @Namespace private var segmentNS

    var body: some View {
        ScrollView {
            FoldReader { info in
                if let fold = info.verticalFold() {
                    // iPhone Duo inner display: words on the left, the card on the right; never across the fold.
                    FoldColumns {
                        VStack(alignment: .leading, spacing: 22) {
                            ScreenTitle(text: segment.rawValue)
                                .contentTransition(.opacity)
                            segmentPicker
                            if segment == .card { hint }
                        }
                        .padding(.leading, 20)
                    } trailing: {
                        segmentContent
                            .frame(maxWidth: min(420, max(0, info.width - fold.upperBound - 40)))
                            .frame(maxWidth: .infinity)
                            .padding(.trailing, 20)
                    }
                    .padding(.top, 12)
                } else {
                    VStack(alignment: .leading, spacing: 22) {
                        ScreenTitle(text: segment.rawValue)
                            .contentTransition(.opacity)
                            .padding(.top, 12)
                        segmentPicker
                        segmentContent
                        if segment == .card { hint }
                    }
                    .padding(.horizontal, 20)
                    .readableWidth(460)
                }
            }
            .padding(.bottom, 24)
            .animation(Theme.spring, value: segment)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.selection, trigger: segment)
        .task {
            if !store.hasLoadedCredits { await store.refreshCredits() }
            if store.profile == nil { await store.refreshProfile() }
        }
    }

    @ViewBuilder
    private var segmentContent: some View {
        if segment == .card {
            card
                .transition(.opacity)
        } else {
            guestPasses
                .transition(.opacity)
        }
    }

    private var hint: some View {
        Text("Show this at the front desk when you arrive.")
            .font(Typo.secondary)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
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

    private var member: MemberIdentity { auth.identity(with: store.profile) }

    private var card: some View {
        VStack(spacing: 0) {
            HStack {
                Wordmark(color: Theme.cream, markSize: 28, textSize: 18, creamMark: true)
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
                    HStack(spacing: 12) {
                        MemberAvatar(path: store.profile?.photoUrl) {
                            Text(member.initials)
                                .font(Typo.font(15, .regular, relativeTo: .subheadline))
                                .foregroundStyle(Theme.fixedInk)
                                .frame(width: 40, height: 40)
                                .background(Color(hex: 0xFBE0E2), in: Circle())
                        }
                        .frame(width: 40, height: 40)
                        Text(member.shortName)
                            .font(Typo.font(28, .light, relativeTo: .title))
                            .foregroundStyle(Theme.fixedInk)
                    }
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
        .riseIn(hasAppeared)
        .onAppear { withAnimation(Motion.choose(Motion.easeLong, calm: calm)) { hasAppeared = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Member card for \(member.displayName)")
    }

    @ViewBuilder
    private var qr: some View {
        // The front desk scans the member's profile id (not the sign-in account id).
        if let id = store.profile?.profileId, !id.isEmpty,
           let image = QRCode.image(for: id, foreground: UIColor(hex: 0x1A1418), background: UIColor(hex: 0xF6EEE7)) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .accessibilityLabel("Member QR code")
        } else if store.hasLoadedProfile {
            Button {
                Task { await store.refreshProfile() }
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20, weight: .light))
                    Text("Couldn't load your member code.\nTap to try again.")
                        .font(Typo.secondary)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Theme.fixedInk.opacity(0.7))
                .frame(width: 200, height: 200)
                .background(Theme.fixedInk.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
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
