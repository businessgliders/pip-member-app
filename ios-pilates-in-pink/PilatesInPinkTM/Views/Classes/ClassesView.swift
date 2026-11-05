import SwiftUI

struct ClassesView: View {
    @Environment(StudioStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var vm = ScheduleViewModel()
    @State private var hasConfigured = false
    @State private var isShowingFilters = false
    @State private var splitSelection: ClassRoute?

    private var isSplit: Bool { hSize == .regular }

    var body: some View {
        Group {
            if isSplit {
                HStack(spacing: 0) {
                    listColumn
                        .frame(width: 400)
                    Rectangle().fill(Theme.hairline).frame(width: 1).ignoresSafeArea()
                    detailColumn
                        .frame(maxWidth: .infinity)
                }
            } else {
                listColumn
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingFilters) {
            FiltersSheet(vm: vm) { draft in
                vm.sessionsForSelectedDay.filter { draft.matches($0) }.count
            }
        }
        .task {
            if !hasConfigured {
                await store.loadSettingsIfNeeded()
                vm.configure(with: store.settings)
                hasConfigured = true
            }
            applyPendingFilter()
            await vm.load()
        }
        .onChange(of: store.settings) { _, settings in
            vm.configure(with: settings)
            Task { await vm.load() }
        }
        .onChange(of: store.scheduleVersion) { _, _ in
            Task { await vm.load() }
        }
        .onChange(of: router.pendingFilterToken) { _, _ in
            applyPendingFilter()
        }
        .onChange(of: vm.selectedDay) { _, _ in
            if isSplit { splitSelection = nil }
        }
    }

    private func applyPendingFilter() {
        guard let family = router.consumePendingFilter() else { return }
        withAnimation(Theme.spring) { vm.filters = ClassFilters(families: [family]) }
    }

    // MARK: List

    private var listColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    ScreenTitle(text: "Classes")
                    Spacer()
                    filtersButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                WeekStripView(vm: vm)
                    .padding(.horizontal, 12)

                if !vm.filters.isEmpty {
                    activeFilters
                }

                list
                    .animation(Theme.softSpring, value: vm.filteredSessionsForSelectedDay)
                    .animation(Theme.softSpring, value: vm.selectedDay)
            }
            .readableWidth()
        }
        .scrollIndicators(.hidden)
        .floatingNavClearance()
        .refreshable {
            await vm.load()
            await store.refreshAll()
        }
    }

    private var filtersButton: some View {
        Button { isShowingFilters = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .light))
                Text(vm.filters.isEmpty ? "Filters" : "Filters (\(vm.filters.count))")
                    .font(Typo.font(15, .regular, relativeTo: .subheadline))
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableCardStyle())
        .glass(Capsule(), interactive: true)
        .accessibilityLabel(vm.filters.isEmpty ? "Filters" : "Filters, \(vm.filters.count) active")
    }

    private var activeFilters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button { isShowingFilters = true } label: {
                    Chip(text: "Filters (\(vm.filters.count))", style: .pink)
                }
                .buttonStyle(.plain)
                Rectangle().fill(Theme.hairline).frame(width: 1, height: 20)
                ForEach(vm.filters.labels, id: \.self) { label in
                    Chip(text: label, style: .blush)
                }
                Button {
                    withAnimation(Theme.spring) { vm.filters = ClassFilters() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 30, height: 30)
                        .background(Theme.card, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear filters")
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .transition(.opacity)
    }

    @ViewBuilder
    private var list: some View {
        if vm.isShowingSkeleton && vm.sessions.isEmpty {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    RowSkeleton()
                    Hairline().padding(.leading, 20)
                }
            }
        } else if let error = vm.error, vm.sessions.isEmpty {
            ErrorCard(error: error, actionTitle: "Try again") {
                Task { await vm.load() }
            }
            .padding(.horizontal, 20)
        } else if vm.filteredSessionsForSelectedDay.isEmpty {
            emptyDay
                .padding(.horizontal, 20)
        } else {
            VStack(spacing: 0) {
                Hairline()
                ForEach(vm.filteredSessionsForSelectedDay) { session in
                    Button {
                        open(session)
                    } label: {
                        ClassRowView(
                            session: session,
                            isHighlighted: isSplit && splitSelection?.sessionId == session.sessionId
                        )
                    }
                    .buttonStyle(PressableCardStyle())
                    Hairline()
                }
            }
        }
    }

    @ViewBuilder
    private var emptyDay: some View {
        if !vm.filters.isEmpty && !vm.sessionsForSelectedDay.isEmpty {
            EmptyStateCard(
                systemImage: "line.3.horizontal.decrease",
                title: "No matches today",
                message: "Try another day, or clear your filters to see every class.",
                actionTitle: "Clear filters"
            ) {
                withAnimation(Theme.spring) { vm.filters = ClassFilters() }
            }
        } else {
            EmptyStateCard(
                systemImage: "moon.stars",
                title: "A quiet day in the studio",
                message: "No classes on this day — pick another date above."
            )
        }
    }

    private func open(_ session: ScheduleSession) {
        let route = ClassRoute(sessionId: session.sessionId, startsAt: session.startDate)
        if isSplit {
            withAnimation(Theme.spring) { splitSelection = route }
        } else {
            router.classesPath.append(.classDetail(route))
        }
    }

    // MARK: Detail column (iPad)

    @ViewBuilder
    private var detailColumn: some View {
        if let route = splitSelection {
            ClassDetailView(route: route, isEmbedded: true)
                .id(route)
                .transition(.opacity)
        } else {
            VStack(spacing: 14) {
                BrandMark(size: 56)
                Text("Choose a class")
                    .font(Typo.font(24, .light, relativeTo: .title2))
                    .foregroundStyle(Theme.ink)
                Text("Pick a class on the left to see details and reserve your reformer.")
                    .font(Typo.secondary)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.trailing, 84)
        }
    }
}
