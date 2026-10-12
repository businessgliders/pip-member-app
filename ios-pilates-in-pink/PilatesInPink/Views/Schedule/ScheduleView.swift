import SwiftUI

struct ScheduleView: View {
    @Environment(StudioStore.self) private var store
    @State private var vm = ScheduleViewModel()
    @State private var hasStarted: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    WeekStripView(vm: vm)

                    NextClassCard(
                        booking: store.nextBooking,
                        stationNumber: store.stationNumber(for: store.nextBooking?.stationId),
                        isLoading: !store.hasLoadedBookings
                    ) {
                        vm.selectToday()
                        Task { await vm.load() }
                        withAnimation(Theme.spring) { proxy.scrollTo("classes", anchor: .top) }
                    }

                    dayHeader
                        .id("classes")

                    classList
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.bottom, Theme.tabBarClearance, for: .scrollContent)
        }
        .background(ScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            let rest = Task { await store.refreshAll() }
            await vm.load()
            await rest.value
        }
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await store.loadSettingsIfNeeded()
            vm.configure(with: store.settings)
            Task { await store.refreshAll() }
            await vm.load()
        }
        .onChange(of: store.scheduleVersion) {
            Task { await vm.load() }
        }
        .onChange(of: store.settings) {
            vm.configure(with: store.settings)
            Task { await vm.load() }
        }
        .sensoryFeedback(.selection, trigger: vm.selectedDay)
    }

    private var header: some View {
        HStack(alignment: .center) {
            ScreenTitle(text: "Classes")
            Spacer()
            CreditsChip(credits: store.credits, isLoading: !store.hasLoadedCredits)
        }
        .padding(.top, 8)
    }

    private var dayHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(StudioTime.isSameDay(vm.selectedDay, vm.today) ? "Today" : StudioTime.format(vm.selectedDay, "EEEE"))
                .font(.title2.weight(.heavy))
                .tracking(-0.5)
                .foregroundStyle(Theme.ink)
            Text(StudioTime.format(vm.selectedDay, "MMMM d"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
            Spacer()
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var classList: some View {
        if vm.isShowingSkeleton {
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in ClassCardSkeleton() }
            }
        } else if let error = vm.error, vm.sessions.isEmpty {
            ErrorCard(error: error, actionTitle: "Try again") {
                Task { await vm.load() }
            }
        } else if vm.sessionsForSelectedDay.isEmpty {
            EmptyStateCard(
                systemImage: "leaf",
                title: "A quiet day in the studio",
                message: "No classes on this day. Tap another date to find your next session."
            )
        } else {
            LazyVStack(spacing: 12) {
                ForEach(vm.sessionsForSelectedDay) { session in
                    if session.isCancelled {
                        ClassCardView(session: session)
                    } else {
                        NavigationLink(value: ClassRoute(sessionId: session.sessionId, startsAt: session.startDate)) {
                            ClassCardView(session: session)
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
            }
            .animation(Theme.spring, value: vm.sessionsForSelectedDay.map(\.id))
        }
    }
}

struct CreditsChip: View {
    let credits: Credits?
    let isLoading: Bool

    var body: some View {
        Group {
            if let credits {
                HStack(spacing: 6) {
                    Image(systemName: credits.isUnlimited ? "infinity" : "circle.hexagongrid.fill")
                        .font(.footnote.weight(.bold))
                    Text(credits.chipLabel)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .foregroundStyle(Theme.caramel)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.caramelSoft, in: Capsule())
                .animation(Theme.spring, value: credits.chipLabel)
                .accessibilityLabel(credits.chipLabel)
            } else if isLoading {
                SkeletonBlock(width: 96, height: 36, radius: 18)
            }
        }
    }
}
