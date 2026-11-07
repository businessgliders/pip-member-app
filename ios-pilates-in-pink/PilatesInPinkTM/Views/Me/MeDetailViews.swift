import SwiftUI

// MARK: - My Reservations

struct ReservationsView: View {
    @Environment(StudioStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PushedHeader(title: "My Reservations")

                if !store.hasLoadedBookings {
                    VStack(spacing: 18) {
                        ForEach(0..<3, id: \.self) { _ in ReservationSkeleton() }
                    }
                    .cardStyle(padding: 18)
                } else if let error = store.bookingsError, store.bookings.isEmpty {
                    ErrorCard(error: error, actionTitle: "Try again") {
                        Task { await store.refreshBookings() }
                    }
                } else if store.upcomingBookings.isEmpty {
                    EmptyStateCard(
                        systemImage: "calendar",
                        title: "Nothing booked yet",
                        message: "Find a class you love and choose your reformer.",
                        showsLogo: true,
                        actionTitle: "Book a Class"
                    ) {
                        router.openClasses()
                    }
                } else {
                    EyebrowText("\(store.upcomingBookings.count) upcoming")
                    VStack(spacing: 0) {
                        ForEach(Array(store.upcomingBookings.enumerated()), id: \.element.id) { index, booking in
                            if index > 0 { Hairline() }
                            Button {
                                router.push(.classDetail(ClassRoute(sessionId: booking.classSessionId, startsAt: booking.startDate)))
                            } label: {
                                ReservationRow(
                                    booking: booking,
                                    session: store.session(for: booking),
                                    reformerNumber: store.stationNumber(for: booking.stationId)
                                )
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .readableWidth()
            .avoidingFold()
            .animation(Motion.ease, value: store.upcomingBookings)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .pushedScreenChrome()
        .logoRefreshable { await store.refreshBookings() }
        .task { await store.loadStationsIfNeeded() }
    }
}

// MARK: - Credits & Membership

struct CreditsView: View {
    @Environment(StudioStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                PushedHeader(title: "Credits & Membership")
                    .padding(.bottom, 8)

                if let credits = store.credits {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowText(credits.memberLabel, color: Theme.caramel)
                        Text(credits.isUnlimited ? "Unlimited" : "\(credits.creditCount)")
                            .font(Typo.font(56, .light, relativeTo: .largeTitle))
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                            .animation(Motion.ease, value: credits.creditCount)
                        Text(credits.isUnlimited ? "Book as many classes as you like." : (credits.creditCount == 1 ? "class credit available" : "class credits available"))
                            .font(Typo.secondary)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .cardStyle(padding: 22)

                    VStack(spacing: 0) {
                        if let name = credits.membershipName, !name.isEmpty {
                            infoRow("Membership", name)
                            Hairline()
                        }
                        if let renews = credits.renewsDate {
                            infoRow("Renews", StudioTime.format(renews, "MMM d, yyyy"))
                            Hairline()
                        }
                        if let expiry = credits.expiryDate {
                            infoRow("Next credit expires", StudioTime.format(expiry, "MMM d, yyyy"))
                            Hairline()
                        }
                        infoRow("Guest passes", "\(credits.guestPassCount)")
                    }
                    .padding(.horizontal, 18)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                } else if let error = store.creditsError {
                    ErrorCard(error: error, actionTitle: "Try again") {
                        Task { await store.refreshCredits() }
                    }
                } else if store.hasLoadedCredits {
                    EmptyStateCard(
                        systemImage: "creditcard",
                        title: "No credits yet",
                        message: "Visit the front desk or our website to pick a membership or class pack."
                    )
                } else {
                    SkeletonBlock(height: 160, radius: Theme.cardRadius)
                }

                Button {} label: { Text("Buy credits — coming soon") }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .disabled(true)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .readableWidth()
            .avoidingFold()
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .pushedScreenChrome()
        .logoRefreshable { await store.refreshCredits() }
        .task { await store.refreshCredits() }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Typo.body).foregroundStyle(Theme.secondaryText)
            Spacer()
            Text(value).font(Typo.body).monospacedDigit().foregroundStyle(Theme.ink)
        }
        .frame(minHeight: 54)
    }
}

// MARK: - Account

struct AccountDetailsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(StudioStore.self) private var store
    @State private var isConfirmingSignOut = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gap) {
                PushedHeader(title: "Account")
                    .padding(.bottom, 8)
                let member = auth.identity(with: store.profile)
                VStack(spacing: 0) {
                    row("First name", member.firstName.isEmpty ? "—" : member.firstName)
                    Hairline()
                    row("Last name", member.lastName.isEmpty ? "—" : member.lastName)
                    Hairline()
                    row("Email", member.email.isEmpty ? "—" : member.email)
                    Hairline()
                    row("Studio", "\(StudioInfo.name) · \(StudioInfo.city)")
                }
                .padding(.horizontal, 18)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

                Text("To update your details, contact the studio and we'll take care of it.")
                    .font(Typo.secondary)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.horizontal, 4)

                Button("Sign out") { isConfirmingSignOut = true }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .padding(.top, 16)

                about
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .readableWidth()
            .avoidingFold()
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .pushedScreenChrome()
        .confirmationDialog("Sign out of Pilates in Pink™?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await auth.signOut() } }
            Button("Stay signed in", role: .cancel) {}
        }
    }

    /// About: the mark, the app version and where it's made.
    private var about: some View {
        VStack(spacing: 10) {
            EyebrowText("About")
            BrandMark(size: 44)
                .padding(.vertical, 4)
            Text("Pilates in Pink™")
                .font(Typo.font(17, .light, relativeTo: .headline))
                .foregroundStyle(Theme.ink)
            Text(versionText)
                .font(Typo.font(13, .regular, relativeTo: .footnote))
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryText)
            Text("Made in Brampton")
                .font(Typo.font(13, .regular, relativeTo: .footnote))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            EyebrowText(label)
            Spacer()
            Text(value)
                .font(Typo.body)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 54)
    }
}

// MARK: - Notifications

struct NotificationsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PushedHeader(title: "Notifications")
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 14) {
                        BrandMark(size: 26)
                            .frame(width: 48, height: 48)
                            .background(Theme.blush, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Welcome to Pilates in Pink™")
                                    .font(Typo.font(16, .medium, relativeTo: .headline))
                                    .foregroundStyle(Theme.ink)
                                Spacer(minLength: 8)
                                Text(StudioTime.format(Date(), "MMM d"))
                                    .font(Typo.font(13, .regular, relativeTo: .footnote))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            Text("Book your class and choose your exact reformer — right from your phone. See you in the studio.")
                                .font(Typo.secondary)
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 18)
                }
                .padding(.horizontal, 18)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .readableWidth()
            .avoidingFold()
        }
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .pushedScreenChrome()
    }
}
