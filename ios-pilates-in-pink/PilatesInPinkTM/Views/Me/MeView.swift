import SwiftUI

struct MeView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(StudioStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @State private var isConfirmingSignOut = false
    @State private var studioSheet: StudioInfoSheet.Section?
    @State private var isShowingGuestNote = false

    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        ScrollView {
            Group {
                if hSize == .regular {
                    // Two columns; on iPhone Duo the gap sits on the fold.
                    FoldColumns {
                        VStack(alignment: .leading, spacing: Theme.gap) {
                            profile.padding(.bottom, 16)
                            studioCard
                        }
                    } trailing: {
                        VStack(alignment: .leading, spacing: Theme.gap) {
                            visitsCard
                            menu.padding(.top, 12)
                            footer
                        }
                    }
                    .readableWidth(1100)
                } else {
                    VStack(alignment: .leading, spacing: Theme.gap) {
                        profile
                            .padding(.bottom, 16)
                        studioCard
                        visitsCard
                        menu
                            .padding(.top, 12)
                        footer
                    }
                    .readableWidth()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { router.mePath.append(.account) } label: {
                    Label("Account settings", systemImage: "gearshape")
                }
            }
        }
        .logoRefreshable { await store.refreshAll() }
        .task {
            if !store.hasLoadedCredits { await store.refreshCredits() }
            if !store.hasLoadedProfile { await store.refreshProfile() }
        }
        .sheet(item: $studioSheet) { section in
            StudioInfoSheet(initial: section)
        }
        .confirmationDialog("Sign out of Pilates in Pink™?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await auth.signOut() } }
            Button("Stay signed in", role: .cancel) {}
        }
        .alert("Guest invites are coming soon", isPresented: $isShowingGuestNote) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("For now, bring your friend along and let the front desk know when you arrive.")
        }
    }

    private var footer: some View {
        Text("Pilates in Pink™ · Brampton, Ontario")
            .font(Typo.font(13, .regular, relativeTo: .footnote))
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
    }

    // MARK: Profile

    private var profile: some View {
        let member = auth.identity(with: store.profile)
        return VStack(spacing: 12) {
            MemberAvatar(path: store.profile?.photoUrl) {
                Text(member.initials)
                    .font(Typo.font(36, .light, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.onPink)
                    .frame(width: 104, height: 104)
                    .background(
                        LinearGradient(colors: [Color(hex: 0xFBE0E2), Color(hex: 0xF7B1BD)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
            }
            .frame(width: 104, height: 104)
            .accessibilityHidden(true)
            Text(member.displayName)
                .font(Typo.font(30, .light, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            EyebrowText(
                store.credits?.memberLabel ?? (store.hasLoadedCredits ? "NO ACTIVE MEMBERSHIP" : " "),
                color: Theme.caramel
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Studio

    private var studioCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                StudioPhoto(name: "studio_brampton")
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(StudioInfo.name) · \(StudioInfo.city)")
                        .font(Typo.font(17, .regular, relativeTo: .headline))
                        .foregroundStyle(Theme.ink)
                    Text(StudioInfo.statusLine())
                        .font(Typo.secondary)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            HStack(spacing: 0) {
                roundAction("info", "Details") { studioSheet = .details }
                roundAction("clock", "Hours") { studioSheet = .hours }
                roundAction("phone", "Call") { if let url = StudioInfo.phoneURL { openURL(url) } }
                roundAction("map", "Map") { if let url = StudioInfo.mapsURL { openURL(url) } }
            }
        }
        .cardStyle(padding: 20)
    }

    private func roundAction(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 48, height: 48)
                    .background(Theme.blush, in: Circle())
                Text(title)
                    .font(Typo.font(13, .regular, relativeTo: .footnote))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: Visits

    private var visitsCard: some View {
        let cal = StudioTime.calendar
        let now = Date()
        let range = cal.range(of: .day, in: .month, for: now) ?? 1..<31
        let firstOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let leading = cal.component(.weekday, from: firstOfMonth) - 1
        let today = cal.component(.day, from: now)
        let visited = store.visitDaysThisMonth
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    EyebrowText("Classes this month")
                    Text("\(store.classesThisMonth)")
                        .font(Typo.font(44, .light, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .animation(Motion.ease, value: store.classesThisMonth)
                }
                Spacer()
                Text(StudioTime.format(now, "MMMM"))
                    .font(Typo.secondary)
                    .foregroundStyle(Theme.secondaryText)
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"].indices, id: \.self) { i in
                    Text(["S", "M", "T", "W", "T", "F", "S"][i])
                        .font(Typo.font(11, .medium, relativeTo: .caption2))
                        .foregroundStyle(Theme.secondaryText)
                }
                ForEach(0..<leading, id: \.self) { i in
                    Color.clear.frame(height: 14).id("lead\(i)")
                }
                ForEach(Array(range), id: \.self) { day in
                    Circle()
                        .fill(visited.contains(day) ? Theme.pink : (day <= today ? Theme.taken : Color.clear))
                        .overlay(Circle().strokeBorder(day > today ? Theme.hairline : Color.clear, lineWidth: 1))
                        .overlay {
                            if day == today {
                                Circle().strokeBorder(Theme.ink, lineWidth: 1)
                            }
                        }
                        .frame(width: 14, height: 14)
                }
            }
            .accessibilityHidden(true)
        }
        .cardStyle(padding: 20)
        .accessibilityElement(children: .combine)
    }

    // MARK: Menu

    private var menu: some View {
        VStack(spacing: 0) {
            menuRow("calendar", "My Reservations", detail: store.upcomingBookings.isEmpty ? nil : "\(store.upcomingBookings.count)") {
                router.mePath.append(.reservations)
            }
            divider
            menuRow("creditcard", "Credits & Membership", detail: store.credits?.chipLabel) {
                router.mePath.append(.credits)
            }
            divider
            menuRow("person.2", "Invite a Guest", detail: "Soon") { isShowingGuestNote = true }
            divider
            menuRow("bell", "Notifications") { router.mePath.append(.notifications) }
            divider
            menuRow("person.crop.circle", "Account") { router.mePath.append(.account) }
            divider
            menuRow("questionmark.circle", "Help & Support") {
                if let url = StudioInfo.helpURL { openURL(url) }
            }
            divider
            menuRow("rectangle.portrait.and.arrow.right", "Sign out", showsChevron: false) {
                isConfirmingSignOut = true
            }
        }
        .padding(.horizontal, 18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var divider: some View { Hairline().padding(.leading, 40) }

    private func menuRow(
        _ icon: String,
        _ title: String,
        detail: String? = nil,
        showsChevron: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 24)
                Text(title)
                    .font(Typo.body)
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(Typo.secondary)
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryText)
                }
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }
}
