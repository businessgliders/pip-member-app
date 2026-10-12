import SwiftUI

struct ClassDetailView: View {
    @Environment(StudioStore.self) private var store
    @State private var vm: ClassDetailViewModel
    @State private var isConfirmingCancel: Bool = false

    init(route: ClassRoute) {
        _vm = State(initialValue: ClassDetailViewModel(route: route))
    }

    private var policy: CancellationPolicy? {
        guard let session = vm.session, let minutes = store.settings?.cancellationWindowMinutes else { return nil }
        return CancellationPolicy(start: session.startDate, windowMinutes: minutes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let session = vm.session {
                    header(session)
                    if let error = vm.actionError {
                        ErrorCard(error: error, onDismiss: {
                            withAnimation(Theme.spring) { vm.actionError = nil }
                        })
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    pickerSection
                    contextLine
                } else if let error = vm.loadError {
                    ErrorCard(error: error, actionTitle: "Try again") {
                        Task { await vm.load(store: store) }
                    }
                    .padding(.top, 12)
                } else {
                    loadingSkeleton
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
            .animation(Theme.spring, value: vm.actionError)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground())
        .safeAreaInset(edge: .bottom) {
            if vm.session != nil {
                actionBar
            }
        }
        .overlay(alignment: .top) {
            if let toast = vm.toast {
                ToastView(text: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: vm.toast)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .refreshable { await vm.load(store: store) }
        .task { await vm.load(store: store) }
        .sheet(item: $vm.confirmation) { confirmation in
            BookingConfirmationSheet(confirmation: confirmation)
        }
        .alert(
            "Cancel this booking?",
            isPresented: $isConfirmingCancel
        ) {
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
    }

    // MARK: Header

    private func header(_ session: ScheduleSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ScreenTitle(text: session.name)
            Text("\(StudioTime.format(session.startDate, "EEE, MMM d")) · \(StudioTime.time(session.startDate))")
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            HStack(spacing: 8) {
                Text(metaLine(session))
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                if session.isSub {
                    Chip(text: "Sub", style: .outline)
                }
            }
            statusChip(session)
                .padding(.top, 4)
        }
    }

    private func metaLine(_ session: ScheduleSession) -> String {
        var parts: [String] = []
        if let instructor = session.instructorName, !instructor.isEmpty { parts.append(instructor) }
        if let level = session.classLevel, !level.isEmpty { parts.append(level) }
        parts.append("\(session.durationMinutes) min")
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func statusChip(_ session: ScheduleSession) -> some View {
        switch vm.mode {
        case .booked:
            if let number = store.stationNumber(for: vm.myStationId) {
                Chip(text: "Booked on Reformer \(number)", style: .caramel, systemImage: "checkmark")
            } else {
                Chip(text: "Booked", style: .caramel, systemImage: "checkmark")
            }
        case .waitlisted:
            Chip(text: "You're on the waitlist", style: .blush)
        case .full:
            Chip(text: "Full · Join the waitlist", style: .blush)
        case .cancelled:
            Chip(text: "This class was cancelled", style: .outline)
        case .finished:
            Chip(text: "This class has started", style: .outline)
        case .bookable:
            Text(session.spotsLeft == 1 ? "1 spot left" : "\(session.spotsLeft) spots left")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(session.spotsLeft <= 2 ? Theme.caramel : Theme.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(session.spotsLeft <= 2 ? Theme.caramelSoft : Theme.softPink, in: Capsule())
        case .loading:
            EmptyView()
        }
    }

    // MARK: Picker

    @ViewBuilder
    private var pickerSection: some View {
        if store.stations.isEmpty {
            VStack(spacing: 12) {
                SkeletonBlock(width: 120, height: 16)
                ForEach(0..<4, id: \.self) { _ in
                    HStack(spacing: 12) {
                        SkeletonBlock(height: 72, radius: 18)
                        SkeletonBlock(height: 72, radius: 18)
                    }
                }
            }
            .padding(16)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if vm.isBooked {
                    Text("Tap a free reformer to switch spots.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
                ReformerPickerView(
                    stations: store.stations,
                    stateFor: { vm.tileState(for: $0) },
                    onTap: { station in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) { vm.toggle(station) }
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var contextLine: some View {
        if let policy, vm.mode == .bookable || vm.isBooked || vm.mode == .full {
            let inside = policy.isInsideWindow()
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: inside ? "clock" : "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(inside ? Theme.caramel : Theme.secondaryText)
                Text(policy.contextLine())
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
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

    // MARK: Action bar

    private var selectedNumber: Int? {
        guard let id = vm.selectedStationId else { return nil }
        return store.stationNumber(for: id)
    }

    private var actionBar: some View {
        VStack(spacing: 10) {
            switch vm.mode {
            case .bookable:
                primaryButton(
                    title: selectedNumber.map { "Book Reformer \($0)" } ?? "Choose a reformer",
                    enabled: selectedNumber != nil
                ) {
                    Task { await vm.book(store: store) }
                }
            case .booked:
                primaryButton(
                    title: selectedNumber.map { "Move to Reformer \($0)" } ?? "Change reformer",
                    enabled: selectedNumber != nil
                ) {
                    Task { await vm.changeReformer(store: store) }
                }
                Button("Cancel booking") { isConfirmingCancel = true }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .disabled(vm.isWorking)
            case .full:
                primaryButton(title: "Join waitlist", enabled: true) {
                    Task { await vm.joinWaitlist(store: store) }
                }
            case .waitlisted:
                Button("Leave waitlist") {
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
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
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
                ProgressView().tint(Theme.onPink)
            } else {
                Text(title).contentTransition(.numericText())
            }
        }
        .buttonStyle(PillButtonStyle())
        .disabled(!enabled || vm.isWorking)
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonBlock(width: 240, height: 38)
            SkeletonBlock(width: 200, height: 20)
            SkeletonBlock(width: 160, height: 16)
            SkeletonBlock(width: 100, height: 26, radius: 13)
            SkeletonBlock(height: 360, radius: Theme.cardRadius)
                .padding(.top, 8)
        }
    }
}
