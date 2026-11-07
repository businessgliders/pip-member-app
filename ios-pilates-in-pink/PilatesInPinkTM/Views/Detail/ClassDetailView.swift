import SwiftUI
import UIKit

struct ClassDetailView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var vm: ClassDetailViewModel
    @State private var isConfirmingCancel = false
    @State private var calendarNote: String?
    @State private var calendarAdded = 0
    @State private var isWide = false
    /// Where the inline actions sit inside the visible scroll area, and how much of the
    /// bottom is covered (tab bar), so a new selection can scroll the button into view.
    @State private var actionsFrame: CGRect = .zero
    @State private var scrollMetrics = ScrollMetrics()
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.calmMotion) private var calm
    let isEmbedded: Bool

    init(route: ClassRoute, isEmbedded: Bool = false) {
        _vm = State(initialValue: ClassDetailModels.model(for: route))
        self.isEmbedded = isEmbedded
    }

    private var policy: CancellationPolicy? {
        guard let session = vm.session, let minutes = store.settings?.cancellationWindowMinutes else { return nil }
        return CancellationPolicy(start: session.startDate, windowMinutes: minutes)
    }

    var body: some View {
        Group {
            if usesTwoPanes {
                twoPaneLayout
            } else {
                singleColumn
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height * 1.1
        } action: { isWide = $0 }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { detailToolbar }
        .animation(Motion.choose(Motion.ease, calm: calm), value: vm.toast)
        .animation(Motion.choose(Motion.ease, calm: calm), value: calendarNote)
        .task {
            await vm.load(store: store)
            await store.loadClassTypesIfNeeded()
        }
        .sheet(item: $vm.confirmation) { confirmation in
            BookingConfirmationSheet(confirmation: confirmation)
        }
        .alert("Cancel this booking?", isPresented: $isConfirmingCancel) {
            Button("Cancel booking", role: .destructive) {
                Task { await vm.cancel(store: store, windowText: policy?.windowText ?? "the cancellation window") }
            }
            Button("Keep my spot", role: .cancel) {}
        } message: {
            Text(cancelMessage)
        }
        .alert(item: $vm.resultMessage) { result in
            Alert(title: Text(result.title), message: Text(result.message), dismissButton: .default(Text("OK")))
        }
        // A new booking's success haptic belongs to the "You're booked" moment, so it plays once.
        .sensoryFeedback(trigger: vm.successTick) { _, _ in vm.confirmation == nil ? .success : nil }
        .sensoryFeedback(.warning, trigger: vm.errorTick)
        .sensoryFeedback(.selection, trigger: vm.selectedStationId)
        .sensoryFeedback(.success, trigger: calendarAdded)
    }

    /// Hero + details beside the picker when the screen is wide (iPad, iPhone Duo inner display
    /// held landscape, large iPhones in landscape). The split-view detail column stays one column.
    private var usesTwoPanes: Bool {
        !isEmbedded && hSize == .regular && isWide
    }

    // MARK: Layouts

    private var singleColumn: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 0) {
                    hero(fraction: 0.4)
                    sheetSurface {
                        if let session = vm.session {
                            header(session)
                            actionErrorCard
                            Hairline()
                            pickerSection
                            contextLine
                            inlineActions
                            aboutSection(session)
                        } else {
                            loadingOrError
                        }
                    }
                }
                .padding(.bottom, Self.tabBarClearance)
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(.container, edges: .top)
            .refreshable { await vm.load(store: store) }
            .modifier(RevealActionsOnSelect(
                selection: vm.selectedStationId,
                actionsFrame: actionsFrame,
                metrics: $scrollMetrics,
                calm: calm,
                reader: reader
            ))
            .overlay(alignment: .top) { toastOverlay }
        }
    }

    /// Extra room below the content so the last reformer row and the button always scroll
    /// fully clear of the floating tab bar (on top of the system's own safe-area inset).
    static let tabBarClearance: CGFloat = 40
    fileprivate static let actionsID = "detail-actions"

    @ViewBuilder
    private var twoPaneLayout: some View {
#if canImport(SwiftUI, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            ArrangementView {
                infoPane
            } secondary: {
                bookingPane
            }
            .arrangementViewStyle(.split)
        } else {
            twoPaneFallback
        }
#else
        twoPaneFallback
#endif
    }

    private var twoPaneFallback: some View {
        HStack(spacing: 0) {
            infoPane.frame(maxWidth: .infinity)
            Rectangle().fill(Theme.hairline).frame(width: 1).ignoresSafeArea()
            bookingPane.frame(maxWidth: .infinity)
        }
    }

    /// Left pane: photo, class details and what to expect.
    private var infoPane: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero(fraction: 0.5)
                sheetSurface {
                    if let session = vm.session {
                        header(session)
                        aboutSection(session)
                    } else {
                        loadingOrError
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.container, edges: .top)
        .refreshable { await vm.load(store: store) }
        .background(Theme.background.ignoresSafeArea())
    }

    /// Right pane: reformer picker with the booking actions inline below it.
    private var bookingPane: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if vm.session != nil {
                        actionErrorCard
                        pickerSection
                        contextLine
                        inlineActions
                    } else {
                        SkeletonBlock(height: 300, radius: Theme.cardRadius)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24 + Self.tabBarClearance)
                .frame(maxWidth: Theme.readableWidth)
                .frame(maxWidth: .infinity)
                .animation(Motion.choose(Motion.ease, calm: calm), value: vm.actionError)
            }
            .scrollIndicators(.hidden)
            .modifier(RevealActionsOnSelect(
                selection: vm.selectedStationId,
                actionsFrame: actionsFrame,
                metrics: $scrollMetrics,
                calm: calm,
                reader: reader
            ))
            .overlay(alignment: .top) { toastOverlay }
            .background(Theme.background.ignoresSafeArea())
        }
    }

    private func sheetSurface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            content()
        }
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 28)
        .frame(maxWidth: Theme.readableWidth)
        .frame(maxWidth: .infinity)
        .background(Theme.background)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.sheetRadius, topTrailingRadius: Theme.sheetRadius, style: .continuous))
        .padding(.top, -Theme.sheetRadius)
        .animation(Motion.choose(Motion.ease, calm: calm), value: vm.actionError)
    }

    @ViewBuilder
    private var actionErrorCard: some View {
        if let error = vm.actionError {
            ErrorCard(error: error, onDismiss: {
                withAnimation(Motion.fade) { vm.actionError = nil }
            })
            .transition(Motion.rise(calm: calm))
        }
    }

    @ViewBuilder
    private var loadingOrError: some View {
        if let error = vm.loadError {
            ErrorCard(error: error, actionTitle: "Try again") {
                Task { await vm.load(store: store) }
            }
        } else {
            loadingSkeleton
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = vm.toast ?? calendarNote {
            ToastView(text: toast)
                .padding(.top, 8)
                .padding(.horizontal, 16)
                .transition(Motion.rise(calm: calm))
        }
    }

    // MARK: Hero

    private func hero(fraction: CGFloat) -> some View {
        // Wide photo, top-aligned so faces and raised arms stay in frame;
        // falls back to the square photo, then the gradient.
        StudioPhoto(
            name: vm.session?.widePhotoName ?? "studio_brampton",
            fallbacks: vm.session.map { [$0.photoName] } ?? [],
            alignment: .top,
            tone: .deep,
            fadeIn: true
        )
            .containerRelativeFrame(.vertical) { height, _ in height * fraction }
            .frame(maxWidth: .infinity)
            .overlay {
                LinearGradient(colors: [Color.black.opacity(0.32), .clear], startPoint: .top, endPoint: .center)
            }
            .overlay(alignment: .bottomLeading) {
                if let family = vm.session?.family {
                    PhotoLabelPill(text: family.displayName)
                        .padding(.leading, 24)
                        .padding(.bottom, Theme.sheetRadius + 16)
                }
            }
            .clipped()
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var detailToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if let session = vm.session {
                Button { addToCalendar(session) } label: {
                    Label("Add to Calendar", systemImage: "calendar.badge.plus")
                }
                ShareLink(
                    item: StudioInfo.website ?? URL(string: "https://www.pilatesinpinkstudio.com")!,
                    subject: Text(session.name),
                    message: Text(shareMessage(session))
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func shareMessage(_ session: ScheduleSession) -> String {
        "Join me for \(session.name) at Pilates in Pink™ Brampton — \(StudioTime.format(session.startDate, "EEEE, MMM d")) at \(StudioTime.time(session.startDate))."
    }

    // MARK: Header

    private func header(_ session: ScheduleSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            EyebrowText(StudioTime.format(session.startDate, "EEEE, MMM d"))
            ScreenTitle(text: session.name + (session.isSub ? " (Sub)" : ""), size: 32)

            HStack(alignment: .center) {
                Text(StudioTime.timeRange(session.startDate, session.endDate))
                    .font(Typo.font(28, .light, relativeTo: .title))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let instructor = session.instructorName, !instructor.isEmpty {
                    infoLine("Instructor", instructor)
                }
                if let level = session.classLevel, !level.isEmpty {
                    infoLine("Level", level)
                }
            }

            statusChip(session)
        }
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        (Text("\(label): ").foregroundStyle(Theme.secondaryText) + Text(value).foregroundStyle(Theme.ink))
            .font(Typo.body)
    }

    @ViewBuilder
    private func statusChip(_ session: ScheduleSession) -> some View {
        switch vm.mode {
        case .booked:
            HStack(spacing: 6) {
                Image(systemName: "checkmark").font(.system(size: 12, weight: .medium))
                Text(store.stationNumber(for: vm.myStationId).map { "Booked · Reformer \($0)" } ?? "Booked")
            }
            .font(Typo.font(15, .medium, relativeTo: .subheadline))
            .foregroundStyle(Theme.caramel)
        case .waitlisted:
            Chip(text: "You're on the waitlist", style: .blush)
        case .full:
            Chip(text: "Full · waitlist open", style: .blush)
        case .cancelled:
            Chip(text: "This class was cancelled", style: .outline)
        case .finished:
            Chip(text: "This class has started", style: .outline)
        case .bookable:
            Chip(text: session.spotsLeft == 1 ? "1 spot left" : "\(session.spotsLeft) spots left", style: .soft)
                .monospacedDigit()
        case .loading:
            EmptyView()
        }
    }

    // MARK: Picker

    @ViewBuilder
    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                SectionHeader(text: vm.isBooked ? "Your reformer" : "Choose your reformer")
                Spacer()
            }
            if vm.isBooked {
                Text("Tap a free reformer to switch spots.")
                    .font(Typo.secondary)
                    .foregroundStyle(Theme.secondaryText)
            }
            if store.stations.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 10) {
                            SkeletonBlock(height: 60, radius: 16)
                            SkeletonBlock(height: 60, radius: 16)
                        }
                    }
                }
            } else {
                ReformerPickerView(
                    stations: store.stations,
                    stateFor: { vm.tileState(for: $0) },
                    onTap: { station in
                        withAnimation(Motion.choose(Motion.tileFill, calm: calm)) { vm.toggle(station) }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var contextLine: some View {
        if let policy, vm.mode == .bookable || vm.isBooked || vm.mode == .full {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: policy.isInsideWindow() ? "clock" : "calendar")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Theme.secondaryText)
                Text(policy.contextLine())
                    .font(Typo.secondary)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func aboutSection(_ session: ScheduleSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let description = store.description(forClassType: session.classTypeId) {
                Hairline()
                SectionHeader(text: "What to Expect")
                Text(description)
                    .font(Typo.body)
                    .lineSpacing(4)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Hairline()
            HStack(spacing: 0) {
                factColumn("Duration", "\(session.durationMinutes) min")
                Rectangle().fill(Theme.hairline).frame(width: 1, height: 40)
                factColumn("Level", (session.classLevel?.isEmpty == false ? session.classLevel : nil) ?? "All levels")
            }
        }
    }

    private func factColumn(_ label: String, _ value: String) -> some View {
        VStack(spacing: 6) {
            EyebrowText(label, size: 11)
            Text(value)
                .font(Typo.font(17, .regular, relativeTo: .body))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var cancelMessage: String {
        guard let policy else {
            return "We'll let you know right away whether your credit is refunded."
        }
        if policy.isInsideWindow() {
            return "This class starts within \(policy.windowText), so cancelling now will use your credit."
        }
        return "You're cancelling before \(policy.deadlineText), so your credit will be refunded."
    }

    // MARK: Calendar

    private func addToCalendar(_ session: ScheduleSession) {
        let number = vm.isBooked ? store.stationNumber(for: vm.myStationId) : nil
        Task {
            do {
                let outcome = try await CalendarService.addClass(
                    title: session.name,
                    start: session.startDate,
                    end: session.endDate,
                    reformerNumber: number
                )
                if outcome == .added {
                    calendarAdded += 1
                    flashNote("Added to your calendar")
                } else if let url = URL(string: UIApplication.openSettingsURLString) {
                    flashNote("Turn on calendar access in Settings")
                    try? await Task.sleep(for: .seconds(1.2))
                    openURL(url)
                }
            } catch {
                flashNote("Couldn't add it just now — try again")
            }
        }
    }

    private func flashNote(_ text: String) {
        calendarNote = text
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            if calendarNote == text { calendarNote = nil }
        }
    }

    // MARK: Inline actions

    private var selectedNumber: Int? {
        guard let id = vm.selectedStationId else { return nil }
        return store.stationNumber(for: id)
    }

    /// Sits in the flow directly under the legend and cancellation line — nothing floats
    /// over the reformer grid.
    private var inlineActions: some View {
        VStack(spacing: 4) {
            switch vm.mode {
            case .bookable:
                if let number = selectedNumber {
                    primaryButton(title: "Reserve Reformer \(number)", number: number, enabled: true) {
                        Task { await vm.book(store: store) }
                    }
                    .transition(Motion.rise(calm: calm))
                } else {
                    Text("Tap a reformer to choose your spot.")
                        .font(Typo.secondary)
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            case .booked:
                primaryButton(title: "Change Reformer", enabled: selectedNumber != nil) {
                    Task { await vm.changeReformer(store: store) }
                }
                Button("Cancel booking") { isConfirmingCancel = true }
                    .buttonStyle(QuietButtonStyle())
                    .disabled(vm.isWorking)
            case .full:
                primaryButton(title: "Join Waitlist", enabled: true) {
                    Task { await vm.joinWaitlist(store: store) }
                }
            case .waitlisted:
                Button("Leave Waitlist") {
                    Task { await vm.leaveWaitlist(store: store) }
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .disabled(vm.isWorking)
            case .cancelled:
                Button("This class was cancelled") {}
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .disabled(true)
            case .finished:
                Button("This class has started") {}
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .disabled(true)
            case .loading:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
        // A little room under the button so scrolling to it never leaves it tight to the tab bar.
        .padding(.bottom, 8)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .scrollView) } action: { actionsFrame = $0 }
        .id(Self.actionsID)
        // The button fades and rises in; changing the selection rolls the number.
        .animation(Motion.choose(Motion.easeLong, calm: calm), value: vm.selectedStationId)
    }

    private func primaryButton(
        title: String,
        number: Int? = nil,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            if vm.isWorking {
                ProgressView().tint(Theme.primaryLabel)
            } else if let number {
                Text(title).contentTransition(.numericText(value: Double(number)))
            } else {
                Text(title)
            }
        }
        .buttonStyle(PillButtonStyle())
        .disabled(!enabled || vm.isWorking)
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonBlock(width: 140, height: 12)
            SkeletonBlock(width: 240, height: 34)
            SkeletonBlock(width: 200, height: 28)
            SkeletonBlock(width: 160, height: 16)
            SkeletonBlock(height: 300, radius: Theme.cardRadius)
                .padding(.top, 8)
        }
    }
}

// MARK: - Reveal the inline button

/// The scroll view's visible height and how much of its bottom is covered (tab bar, home indicator).
struct ScrollMetrics: Equatable {
    var containerHeight: CGFloat = 0
    var bottomInset: CGFloat = 0
}

/// When a reformer is first selected, gently scrolls just enough for the inline button to sit
/// fully above the tab bar. Does nothing if it's already visible.
private struct RevealActionsOnSelect: ViewModifier {
    let selection: String?
    let actionsFrame: CGRect
    @Binding var metrics: ScrollMetrics
    let calm: Bool
    let reader: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: ScrollMetrics.self) { geo in
                ScrollMetrics(containerHeight: geo.containerSize.height, bottomInset: geo.contentInsets.bottom)
            } action: { _, value in
                metrics = value
            }
            .onChange(of: selection) { old, new in
                guard old == nil, new != nil else { return }
                Task { @MainActor in
                    // Let the button lay out before measuring.
                    try? await Task.sleep(for: .milliseconds(80))
                    let visibleBottom = metrics.containerHeight - metrics.bottomInset
                    guard metrics.containerHeight > 0, actionsFrame.maxY > visibleBottom else { return }
                    withAnimation(Motion.choose(Motion.easeLong, calm: calm)) {
                        reader.scrollTo(ClassDetailView.actionsID, anchor: .bottom)
                    }
                }
            }
    }
}
