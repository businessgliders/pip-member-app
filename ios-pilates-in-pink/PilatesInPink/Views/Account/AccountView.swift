import SwiftUI

struct AccountView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(StudioStore.self) private var store
    @State private var isConfirmingSignOut: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(text: "Account")
                    .padding(.top, 16)
                profileCard
                creditsCard
                comingSoonCard
                Button("Sign out") { isConfirmingSignOut = true }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .padding(.top, 4)
                Text("Pilates in Pink · Brampton, Ontario")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, Theme.tabBarClearance, for: .scrollContent)
        .background(ScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.refreshCredits() }
        .task {
            if !store.hasLoadedCredits { await store.refreshCredits() }
        }
        .confirmationDialog("Sign out of Pilates in Pink?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Stay signed in", role: .cancel) {}
        }
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            Text(auth.initials)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 56, height: 56)
                .background(Theme.softPink, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(auth.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(auth.email)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .cardStyle()
    }

    @ViewBuilder
    private var creditsCard: some View {
        if let credits = store.credits {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if credits.isUnlimited {
                        Text("Unlimited")
                            .font(.system(size: 34, weight: .heavy))
                            .tracking(-1)
                            .foregroundStyle(Theme.caramel)
                    } else {
                        Text("\(credits.creditCount)")
                            .font(.system(size: 44, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(Theme.caramel)
                            .contentTransition(.numericText())
                        Text(credits.creditCount == 1 ? "credit available" : "credits available")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                    }
                    Spacer()
                }

                VStack(spacing: 0) {
                    if let name = credits.membershipName, !name.isEmpty {
                        infoRow("Membership", value: name)
                    }
                    if let renews = credits.renewsDate {
                        infoRow("Renews", value: StudioTime.format(renews, "MMM d, yyyy"))
                    }
                    if let expiry = credits.expiryDate, !credits.isUnlimited {
                        infoRow("Next credit expires", value: StudioTime.format(expiry, "MMM d, yyyy"))
                    }
                    infoRow("Guest passes", value: "\(credits.guestPassCount)", isLast: true)
                }
            }
            .cardStyle(padding: 20)
        } else if let error = store.creditsError {
            ErrorCard(error: error, actionTitle: "Try again") {
                Task { await store.refreshCredits() }
            }
        } else if !store.hasLoadedCredits {
            VStack(alignment: .leading, spacing: 12) {
                SkeletonBlock(width: 140, height: 40)
                SkeletonBlock(height: 16)
                SkeletonBlock(height: 16)
            }
            .cardStyle(padding: 20)
        } else {
            EmptyStateCard(
                systemImage: "circle.hexagongrid",
                title: "No credits yet",
                message: "Credit packs and memberships will be available here soon. The front desk can help in the meantime."
            )
        }
    }

    private func infoRow(_ title: String, value: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
            }
            .padding(.vertical, 12)
            if !isLast {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }
        }
    }

    private var comingSoonCard: some View {
        VStack(spacing: 0) {
            comingSoonRow("Buy credits", icon: "creditcard")
            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 52)
            comingSoonRow("Memberships", icon: "star")
            Rectangle().fill(Theme.hairline).frame(height: 1).padding(.leading, 52)
            comingSoonRow("Guest passes", icon: "person.2")
        }
        .cardStyle(padding: 8)
    }

    private func comingSoonRow(_ title: String, icon: String) -> some View {
        Button {} label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 36, height: 36)
                    .background(Theme.blush, in: Circle())
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Chip(text: "Coming soon", style: .outline)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(true)
        .opacity(0.75)
        .accessibilityLabel("\(title), coming soon")
    }
}
