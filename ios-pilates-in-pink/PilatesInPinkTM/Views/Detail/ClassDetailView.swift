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
        .safeAreaInset(edge: .bottom) {
            if vm.session != nil { actionBar }
        }
        .overlay(alignment: .top) { toastOverlay }
    }

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

    /// Right pane: reformer picker with the booking button pinned below.
    private var bookingPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if vm.session != nil {
                    actionErrorCard
                    pickerSection
                    contextLine
                } else {
                    SkeletonBlock(height: 300, radius: Theme.cardRadius)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: Theme.readableWidth)
            .frame(maxWidth: .infinity)
            .animation(Motion.choose(Motion.ease, calm: calm), value: vm.actionError)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            if vm.session != nil { actionBar }
        }
        .overlay(alignment: .top) { toastOverlay }
        .background(Theme.background.ignoresSafeArea())
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
        StudioPhoto(name: vm.session?.photoName ?? "studio_brampton", tone: .deep, fadeIn: true)
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

    // MARK: Action bar

    private var selectedNumber: Int? {
        guard let id = vm.selectedStationId else { return nil }
        return store.stationNumber(for: id)
    }

    private var spotsSuffix: String {
        guard let session = vm.session else { return "" }
        return " · \(session.spotsLeft) left"
    }

    private var actionBar: some View {
        VStack(spacing: 4) {
            switch vm.mode {
            case .bookable:
                primaryButton(
                    title: (selectedNumber.map { "Reserve Reformer \($0)" } ?? "Choose a reformer") + spotsSuffix,
                    enabled: selectedNumber != nil
                ) {
                    Task { await vm.book(store: store) }
                }
            case .booked:
                primaryButton(
                    title: selectedNumber.map { "Move to Reformer \($0)" } ?? "Change Reformer",
                    enabled: selectedNumber != nil
                ) {
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
        .frame(maxWidth: Theme.readableWidth)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        // The reserve label cross-fades its number.
        .animation(Motion.ease, value: vm.selectedStationId)
    }

    private func primaryButton(title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if vm.isWorking {
                ProgressView().tint(Theme.primaryLabel)
            } else {
                Text(title).contentTransition(.numericText())
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
