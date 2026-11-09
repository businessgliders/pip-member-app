import SwiftUI

struct HomeView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(StudioStore.self) private var store
    @Environment(BannerStore.self) private var bannerStore
    @Environment(Router.self) private var router
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(LogoHandoff.self) private var handoff
    @Environment(\.calmMotion) private var calm

    @State private var topInset: CGFloat = 0
    @State private var fold = FoldInfo()
    /// Sections fade and rise once, on first appearance only.
    @State private var revealStep = 0
    @State private var isScrolling = false
    @State private var safariLink: SafariLink?

    /// The studio's banners; the bundled welcome slide only before they've ever loaded.
    private var slides: [HeroSlide] {
        bannerStore.hasBanners ? bannerStore.banners.map(HeroSlide.init(banner:)) : HeroSlide.firstRun
    }

    private var isRegular: Bool { hSize == .regular }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if slides.isEmpty {
                    // No live banners: a compact cream header with the studio pill.
                    topBar
                        .padding(.bottom, 8)
                    sheet
                } else {
                    HeroCarousel(fold: fold.verticalFold(), isScrolling: isScrolling, slides: slides, onAction: handle)
                        .containerRelativeFrame(.vertical) { height, _ in max(420, height * 0.55) }
                        .overlay(alignment: .top) { topBar }

                    sheet
                        .padding(.top, -Theme.sheetRadius)
                }
            }
        }
        .scrollIndicators(.hidden)
        .onScrollPhaseChange { _, phase in
            let scrolling = phase != .idle
            if scrolling != isScrolling { isScrolling = scrolling }
        }
        .ignoresSafeArea(.container, edges: .top)
        .readFold(into: $fold)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { topInset = proxy.safeAreaInsets.top }
                    .onChange(of: proxy.safeAreaInsets.top) { _, value in topInset = value }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .logoRefreshable(topPadding: topBarTop + 54) {
            async let banners: Void = bannerStore.refresh()
            await store.refreshAll()
            await banners
        }
        .safariSheet($safariLink)
        .task(id: handoff.isSplashActive) { await revealSections() }
    }

    private func revealSections() async {
        guard !handoff.isSplashActive, revealStep == 0 else { return }
        for step in 1...3 {
            withAnimation(Motion.choose(Motion.easeLong, calm: calm)) { revealStep = step }
            try? await Task.sleep(for: .seconds(Motion.sectionStagger))
        }
    }

    private func handle(_ action: HeroSlide.Action) {
        switch action {
        case .classes(let family): router.openClasses(family: family)
        case .me: router.openMe()
        case .credits: router.openMe(.credits)
        case .url(let url): safariLink = SafariLink(url: url)
        case .none: break
        }
    }

    // MARK: Floating top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { router.openMe() } label: {
                GlassCircle {
                    MemberAvatar(path: store.profile?.photoUrl) {
                        Text(auth.identity(with: store.profile).initials)
                            .font(Typo.font(15, .medium, relativeTo: .subheadline))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(store.profile?.photoUrl?.isEmpty == false ? 3 : 0)
                }
            }
            .buttonStyle(PressableCardStyle())
            .accessibilityLabel("Your profile")

            if fold.verticalFold() == nil { Spacer() }

            HStack(spacing: 7) {
                LogoMark(size: 22, style: .creamFill)
                    .logoHandoffTarget(.home)
                Text("BRAMPTON")
                    .font(Typo.font(12, .medium, relativeTo: .caption))
                    .tracking(1.8)
            }
            .foregroundStyle(Theme.ink)
            .padding(.leading, 12)
            .padding(.trailing, 16)
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
        .padding(.top, topBarTop)
    }

    /// Below the status bar, and below any camera cut-out that reaches into the bar.
    private var topBarTop: CGFloat {
        let camera = fold.occlusions
            .filter { $0.minY < topInset + 56 }
            .map(\.maxY)
            .max() ?? 0
        return max(topInset, camera) + 6
    }

    // MARK: Cream sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 28) {
            if isRegular {
                FoldColumns {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(text: "Up Next")
                        reservationsCard
                    }
                    .riseIn(revealStep >= 1)
                } trailing: {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(text: "Credits")
                        creditsRow
                    }
                    .riseIn(revealStep >= 2)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(text: "Up Next")
                        reservationsCard
                    }
                    .riseIn(revealStep >= 1)
                    creditsRow
                        .riseIn(revealStep >= 2)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(text: "At the Studio")
                studioTiles
            }
            .riseIn(revealStep >= 3)
        }
        .padding(.horizontal, 20)
        .padding(.top, 30)
        .padding(.bottom, 24)
        .readableWidth(isRegular ? 1100 : Theme.readableWidth)
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
                    LogoMark(size: 40, style: .quiet)
                        .opacity(0.6)
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
        .animation(Motion.choose(Motion.ease, calm: calm), value: store.upcomingBookings.count)
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
                            .contentTransition(.numericText())
                            .animation(Motion.ease, value: credits.summaryLine)
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

    @ViewBuilder
    private var studioTiles: some View {
        if isRegular {
            FoldReader { info in
                if info.verticalFold() != nil {
                    // Two tiles per side, with the gap on the fold.
                    let families = ClassFamily.allCases
                    let half = (families.count + 1) / 2
                    FoldColumns {
                        tileGrid(Array(families.prefix(half)), columns: 2)
                    } trailing: {
                        tileGrid(Array(families.dropFirst(half)), columns: 2)
                    }
                } else {
                    tileGrid(Array(ClassFamily.allCases), columns: info.width >= 760 ? 4 : 3)
                }
            }
        } else {
            tileGrid(Array(ClassFamily.allCases), columns: 2)
        }
    }

    private func tileGrid(_ families: [ClassFamily], columns count: Int) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.gap), count: count)
        return LazyVGrid(columns: columns, spacing: Theme.gap) {
            ForEach(families) { family in
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
