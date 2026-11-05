import SwiftUI

struct HomeView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(StudioStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var topInset: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeroCarousel(onAction: handle)
                    .containerRelativeFrame(.vertical) { height, _ in max(420, height * 0.55) }
                    .overlay(alignment: .top) { topBar }

                sheet
                    .padding(.top, -Theme.sheetRadius)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.container, edges: .top)
        .floatingNavClearance()
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { topInset = proxy.safeAreaInsets.top }
                    .onChange(of: proxy.safeAreaInsets.top) { _, value in topInset = value }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.refreshAll() }
    }

    private func handle(_ action: HeroSlide.Action) {
        switch action {
        case .classes(let family): router.openClasses(family: family)
        case .me: router.openMe()
        }
    }

    // MARK: Floating top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { router.openMe() } label: {
                GlassCircle {
                    Text(auth.initials)
                        .font(Typo.font(15, .medium, relativeTo: .subheadline))
                        .foregroundStyle(Theme.ink)
                }
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("Your profile")

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "location")
                    .font(.system(size: 12, weight: .regular))
                Text("BRAMPTON")
                    .font(Typo.font(12, .medium, relativeTo: .caption))
                    .tracking(1.8)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .glass(Capsule())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Studio: Brampton")

            Spacer()

            GlassCircleButton(systemImage: "envelope", label: "Notifications") {
                router.homePath.append(.notifications)
            }
        }
        .padding(.horizontal, 16)
        .padding(.trailing, hSize == .regular ? 76 : 0)
        .padding(.top, topInset + 6)
    }

    // MARK: Cream sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(text: "Up Next")
                reservationsCard
                creditsRow
            }
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(text: "At the Studio")
                studioTiles
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 12)
        .readableWidth(hSize == .regular ? 980 : Theme.readableWidth)
        .padding(.trailing, hSize == .regular ? 76 : 0)
        .background(
            Theme.background,
            in: UnevenRoundedRectangle(topLeadingRadius: Theme.sheetRadius, topTrailingRadius: Theme.sheetRadius, style: .continuous)
        )
    }

    private var reservationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("My Reservations")
                        .font(Typo.font(17, .medium, relativeTo: .headline))
                        .foregroundStyle(Theme.ink)
                    Text(upcomingText)
                        .font(Typo.secondary)
                        .monospacedDigit()
                        .foregroundStyle(Theme.secondaryText)
                        .contentTransition(.numericText())
                }
                Spacer()
                Button { router.openClasses() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 40, height: 40)
                        .background(Theme.blush, in: Circle())
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("Book a class")
            }

            Hairline()

            if !store.hasLoadedBookings {
                ReservationSkeleton()
            } else if let error = store.bookingsError, store.bookings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(error.title).font(Typo.body).foregroundStyle(Theme.ink)
                    Text(error.message).font(Typo.secondary).foregroundStyle(Theme.secondaryText)
                    Button("Try again") { Task { await store.refreshBookings() } }
                        .buttonStyle(PillButtonStyle(kind: .secondary))
                }
            } else if let next = store.nextBooking {
                Button {
                    router.homePath.append(.classDetail(ClassRoute(sessionId: next.classSessionId, startsAt: next.startDate)))
                } label: {
                    ReservationRow(
                        booking: next,
                        session: store.session(for: next),
                        reformerNumber: store.stationNumber(for: next.stationId)
                    )
                }
                .buttonStyle(PressableCardStyle())
                if store.upcomingBookings.count > 1 {
                    Button { router.homePath.append(.reservations) } label: {
                        Text("See all \(store.upcomingBookings.count)")
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Nothing booked yet")
                        .font(Typo.font(22, .light, relativeTo: .title3))
                        .foregroundStyle(Theme.ink)
                    Text("Your next class is a few taps away.")
                        .font(Typo.secondary)
                        .foregroundStyle(Theme.secondaryText)
                    Button("Book a Class") { router.openClasses() }
                        .buttonStyle(PillButtonStyle())
                }
            }
        }
        .cardStyle(padding: 20)
        .animation(Theme.softSpring, value: store.upcomingBookings.count)
    }

    private var upcomingText: String {
        guard store.hasLoadedBookings else { return " " }
        let count = store.upcomingBookings.count
        return count == 1 ? "1 upcoming" : "\(count) upcoming"
    }

    private var creditsRow: some View {
        Button { router.openMe(.credits) } label: {
            HStack(spacing: 14) {
                Image(systemName: store.credits?.isUnlimited == true ? "infinity" : "circle.hexagongrid")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Theme.blush, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    if let credits = store.credits {
                        Text(credits.summaryLine)
                            .font(Typo.body)
                            .monospacedDigit()
                            .foregroundStyle(Theme.ink)
                        if let renews = credits.renewsDate {
                            Text("Renews \(StudioTime.format(renews, "MMM d"))")
                                .font(Typo.secondary)
                                .foregroundStyle(Theme.secondaryText)
                        } else if let expiry = credits.expiryDate {
                            Text("Next credit expires \(StudioTime.format(expiry, "MMM d"))")
                                .font(Typo.secondary)
                                .foregroundStyle(Theme.secondaryText)
                        }
                    } else if store.hasLoadedCredits {
                        Text(store.creditsError == nil ? "No credits yet" : "Credits unavailable — pull to refresh")
                            .font(Typo.body)
                            .foregroundStyle(Theme.ink)
                    } else {
                        SkeletonBlock(width: 160, height: 14)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Theme.secondaryText)
            }
            .cardStyle(padding: 16)
        }
        .buttonStyle(PressableCardStyle())
    }

    private var studioTiles: some View {
        let count = hSize == .regular ? 4 : 2
        let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.gap), count: count)
        return LazyVGrid(columns: columns, spacing: Theme.gap) {
            ForEach(ClassFamily.allCases) { family in
                Button { router.openClasses(family: family) } label: {
                    StudioPhoto(name: family.imageName)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(alignment: .bottomLeading) {
                            PhotoLabelPill(text: family.displayName, size: 10)
                                .padding(10)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel("\(family.displayName) classes")
            }
        }
    }
}
