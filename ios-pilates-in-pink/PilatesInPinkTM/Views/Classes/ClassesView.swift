import SwiftUI

/// Classes tab. Compact width: a stack that pushes the class. Regular width (iPad, iPhone Duo
/// inner display): a split view with the list on the left and the class on the right.
/// The schedule, selected day, scroll position and open class live here, above both layouts,
/// so folding, unfolding and rotating keep them.
struct ClassesView: View {
    @Environment(StudioStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var vm = ScheduleViewModel()
    @State private var hasConfigured = false
    @State private var isShowingFilters = false
    @State private var scrolledRow: ScheduleSession.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var fold = FoldInfo()

    private var isSplit: Bool { hSize == .regular }

    var body: some View {
        @Bindable var router = router
        Group {
            if isSplit {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    list
                        .navigationSplitViewColumnWidth(min: 320, ideal: sidebarWidth, max: 560)
                } detail: {
                    detailColumn
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack(path: $router.classesPath) {
                    list.appDestinations()
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .readFold(into: $fold)
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
        .onAppear { syncLayout(regular: isSplit) }
        .onChange(of: hSize) { _, size in syncLayout(regular: size == .regular) }
        .onChange(of: router.classesPath) { _, path in
            guard !isSplit else { return }
            if case .classDetail(let route)? = path.last {
                router.classesSelection = route
            } else {
                router.classesSelection = nil
            }
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
    }

    /// The list column ends at the fold on iPhone Duo, so the column divider sits on it.
    private var sidebarWidth: CGFloat {
        if let fold = fold.verticalFold(margin: 300) { return fold.lowerBound }
        return 380
    }

    /// Moves the open class between the pushed stack and the split detail column.
    private func syncLayout(regular: Bool) {
        if regular {
            if case .classDetail(let route)? = router.classesPath.last {
                router.classesSelection = route
            }
            if !router.classesPath.isEmpty { router.classesPath = [] }
            columnVisibility = .all
        } else if let route = router.classesSelection, router.classesPath.isEmpty {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                router.classesPath = [.classDetail(route)]
            }
        }
    }

    private func applyPendingFilter() {
        guard let family = router.consumePendingFilter() else { return }
        withAnimation(Theme.spring) { vm.filters = ClassFilters(families: [family]) }
    }

    // MARK: List

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ScreenTitle(text: "Classes")
                    .padding(.horizontal, 20)

                WeekStripView(vm: vm)
                    .padding(.horizontal, 12)

                if !vm.filters.isEmpty {
                    activeFilters
                }

                rows
                    .animation(Theme.softSpring, value: vm.filteredSessionsForSelectedDay)
                    .animation(Theme.softSpring, value: vm.selectedDay)
            }
            .padding(.bottom, 24)
            .readableWidth()
        }
        .scrollPosition(id: $scrolledRow, anchor: .top)
        .scrollIndicators(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isShowingFilters = true } label: {
                    Label("Filters", systemImage: vm.filters.isEmpty
                          ? "line.3.horizontal.decrease"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel(vm.filters.isEmpty ? "Filters" : "Filters, \(vm.filters.count) active")
            }
        }
        .refreshable {
            await vm.load()
            await store.refreshAll()
        }
        .onChange(of: vm.selectedDay) { _, _ in
            scrolledRow = nil
            if isSplit { router.classesSelection = nil }
        }
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
    private var rows: some View {
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
                    VStack(spacing: 0) {
                        Button {
                            open(session)
                        } label: {
                            ClassRowView(
                                session: session,
                                isHighlighted: isSplit && router.classesSelection?.sessionId == session.sessionId
                            )
                        }
                        .buttonStyle(PressableCardStyle())
                        Hairline()
                    }
                    .id(session.id)
                }
            }
            .scrollTargetLayout()
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
            withAnimation(Theme.spring) { router.classesSelection = route }
        } else {
            router.classesSelection = route
            router.classesPath.append(.classDetail(route))
        }
    }

    // MARK: Detail column

    @ViewBuilder
    private var detailColumn: some View {
        if let route = router.classesSelection {
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
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background.ignoresSafeArea())
        }
    }
}
