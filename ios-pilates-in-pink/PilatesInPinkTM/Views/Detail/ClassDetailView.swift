import SwiftUI
import UIKit

struct ClassDetailView: View {
    @Environment(StudioStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var vm: ClassDetailViewModel
    @State private var isConfirmingCancel = false
    @State private var calendarNote: String?
    @State private var calendarAdded = 0
    let isEmbedded: Bool

    init(route: ClassRoute, isEmbedded: Bool = false) {
        _vm = State(initialValue: ClassDetailViewModel(route: route))
        self.isEmbedded = isEmbedded
    }

    private var policy: CancellationPolicy? {
        guard let session = vm.session, let minutes = store.settings?.cancellationWindowMinutes else { return nil }
        return CancellationPolicy(start: session.startDate, windowMinutes: minutes)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 22) {
                    if let session = vm.session {
                        header(session)
                        if let error = vm.actionError {
                            ErrorCard(error: error, onDismiss: {
                                withAnimation(Theme.spring) { vm.actionError = nil }
                            })
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Hairline()
                        pickerSection
                        contextLine
                        aboutSection(session)
                    } else if let error = vm.loadError {
                        ErrorCard(error: error, actionTitle: "Try again") {
                            Task { await vm.load(store: store) }
                        }
                    } else {
                        loadingSkeleton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.trailing, isEmbedded ? 76 : 0)
                .padding(.top, 26)
                .padding(.bottom, 28)
                .frame(maxWidth: Theme.readableWidth)
                .frame(maxWidth: .infinity)
                .background(Theme.background)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: Theme.sheetRadius, topTrailingRadius: Theme.sheetRadius, style: .continuous))
                .padding(.top, -Theme.sheetRadius)
                .animation(Theme.spring, value: vm.actionError)
            }
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(.container, edges: .top)
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if vm.session != nil { actionBar }
        }
        .overlay(alignment: .top) { topButtons }
        .overlay(alignment: .top) {
            if let toast = vm.toast ?? calendarNote {
                ToastView(text: toast)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: vm.toast)
        .animation(Theme.spring, value: calendarNote)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await vm.load(store: store) }
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
        .sensoryFeedback(.success, trigger: vm.successTick)
        .sensoryFeedback(.warning, trigger: vm.errorTick)
        .sensoryFeedback(.selection, trigger: vm.selectedStationId)
        .sensoryFeedback(.success, trigger: calendarAdded)
    }

    // MARK: Hero

    private var hero: some View {
        StudioPhoto(name: vm.session?.photoName ?? "studio_brampton", tone: .deep, fadeIn: true)
            .containerRelativeFrame(.vertical) { height, _ in height * 0.4 }
            .frame(maxWidth: .infinity)
            .overlay {
                LinearGradient(colors: [Color.black.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
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

    private var topButtons: some View {
        HStack {
            if !isEmbedded { GlassBackButton() }
            Spacer()
            if let session = vm.session {
                ShareLink(
                    item: StudioInfo.website ?? URL(string: "https://www.pilatesinpinkstudio.com")!,
                    subject: Text(session.name),
                    message: Text(shareMessage(session))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .glass(Circle(), interactive: true)
                .accessibilityLabel("Share class")
            }
        }
        .padding(.horizontal, 16)
        .padding(.trailing, isEmbedded ? 76 : 0)
        .padding(.top, 6)
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
                Spacer()
                Button(action: { addToCalendar(session) }) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 48, height: 48)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(PressableCardStyle())
                .glass(RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: true)
                .accessibilityLabel("Add to Calendar")
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.toggle(station) }
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
        .padding(.trailing, isEmbedded ? 72 : 0)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .animation(Theme.spring, value: vm.selectedStationId)
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
