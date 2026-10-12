import Foundation
import Observation

enum ReformerTileState: Equatable {
    case available, selected, taken, mine, outOfService, locked
}

struct ResultMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@Observable
final class ClassDetailViewModel {
    enum Mode: Equatable {
        case loading
        case cancelled
        case finished
        case booked(bookingId: String)
        case waitlisted(entryId: String)
        case full
        case bookable
    }

    let route: ClassRoute
    private(set) var session: ScheduleSession?
    private(set) var taken: [TakenStation] = []
    private(set) var isLoading = true
    private(set) var loadError: FriendlyError?
    var actionError: FriendlyError?
    var selectedStationId: String?
    private(set) var isWorking = false
    var confirmation: BookingConfirmation?
    var resultMessage: ResultMessage?
    private(set) var toast: String?
    private(set) var successTick = 0
    private(set) var errorTick = 0

    private let service = StudioService()

    init(route: ClassRoute) {
        self.route = route
    }

    var mode: Mode {
        guard let session else { return .loading }
        if session.isCancelled { return .cancelled }
        if session.hasStarted { return .finished }
        if let id = session.myBookingId { return .booked(bookingId: id) }
        if let id = session.myWaitlistEntryId { return .waitlisted(entryId: id) }
        if session.isFull { return .full }
        return .bookable
    }

    var isBooked: Bool {
        if case .booked = mode { return true }
        return false
    }

    var myStationId: String? {
        taken.first { $0.isMine == true }?.stationId
    }

    func tileState(for station: Station) -> ReformerTileState {
        if !station.isInService { return .outOfService }
        if let entry = taken.first(where: { $0.stationId == station.id }) {
            return entry.isMine == true ? .mine : .taken
        }
        switch mode {
        case .bookable, .booked:
            return selectedStationId == station.id ? .selected : .available
        default:
            return .locked
        }
    }

    func toggle(_ station: Station) {
        guard tileState(for: station) == .available || tileState(for: station) == .selected else { return }
        selectedStationId = selectedStationId == station.id ? nil : station.id
    }

    // MARK: Loading

    func load(store: StudioStore) async {
        await store.loadSettingsIfNeeded()
        await store.loadStationsIfNeeded()

        let service = self.service
        let dayStart = StudioTime.startOfDay(route.startsAt)
        let dayEnd = StudioTime.addDays(1, to: dayStart)
        let sessionId = route.sessionId

        async let scheduleResult = captureResult { try await service.schedule(from: dayStart, to: dayEnd) }
        async let takenResult = captureResult { try await service.takenStations(sessionId: sessionId) }
        let (sessions, takenRows) = await (scheduleResult, takenResult)

        switch sessions {
        case .success(let rows):
            if let match = rows.first(where: { $0.sessionId == sessionId }) {
                session = match
                loadError = nil
            } else {
                loadError = FriendlyError(
                    kind: .generic,
                    title: "We couldn't find this class",
                    message: "It may have moved. Head back to the schedule to see what's on."
                )
            }
        case .failure(let error):
            if !FriendlyError.isCancellation(error) && session == nil {
                loadError = FriendlyError.from(error)
            }
        }

        if case .success(let rows) = takenRows {
            taken = rows
        }

        if let selected = selectedStationId, taken.contains(where: { $0.stationId == selected }) {
            selectedStationId = nil
        }
        isLoading = false
    }

    // MARK: Actions

    func book(store: StudioStore) async {
        guard let session, let stationId = selectedStationId,
              let station = store.stations.first(where: { $0.id == stationId }) else { return }
        await perform(store: store) {
            try await self.service.bookClass(sessionId: session.sessionId, stationId: stationId)
            self.selectedStationId = nil
            self.confirmation = BookingConfirmation(
                className: session.name,
                reformerNumber: station.number,
                start: session.startDate,
                end: session.endDate
            )
        }
    }

    func changeReformer(store: StudioStore) async {
        guard case .booked(let bookingId) = mode, let stationId = selectedStationId else { return }
        let number = store.stations.first { $0.id == stationId }?.number
        await perform(store: store) {
            try await self.service.changeReformer(bookingId: bookingId, stationId: stationId)
            self.selectedStationId = nil
            self.showToast(number.map { "You're now on Reformer \($0) ✨" } ?? "Reformer updated ✨")
        }
    }

    func cancel(store: StudioStore, windowText: String) async {
        guard case .booked(let bookingId) = mode else { return }
        await perform(store: store) {
            let status = try await self.service.cancelBooking(bookingId: bookingId)
            self.selectedStationId = nil
            if status == "late_cancelled" {
                self.resultMessage = ResultMessage(
                    title: "Booking cancelled",
                    message: "Because it was within \(windowText) of class, this one used your credit. We'd love to see you at another class soon."
                )
            } else {
                self.resultMessage = ResultMessage(
                    title: "Booking cancelled",
                    message: "All set — your credit is back in your account."
                )
            }
        }
    }

    func joinWaitlist(store: StudioStore) async {
        guard let session else { return }
        await perform(store: store) {
            try await self.service.joinWaitlist(sessionId: session.sessionId)
            self.showToast("You're on the waitlist — we'll hold your place in line.")
        }
    }

    func leaveWaitlist(store: StudioStore) async {
        guard case .waitlisted(let entryId) = mode else { return }
        await perform(store: store) {
            try await self.service.leaveWaitlist(entryId: entryId)
            self.showToast("You've left the waitlist.")
        }
    }

    /// Runs a write, maps failures to friendly copy, then always refreshes the seat map and schedule.
    private func perform(store: StudioStore, _ operation: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        actionError = nil
        do {
            try await operation()
            successTick += 1
        } catch {
            if !FriendlyError.isCancellation(error) {
                actionError = FriendlyError.from(error)
                errorTick += 1
                if actionError?.kind == .stationTaken { selectedStationId = nil }
            }
        }
        isWorking = false
        await load(store: store)
        await store.afterMutation()
    }

    private func showToast(_ text: String) {
        toast = text
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.8))
            guard let self, self.toast == text else { return }
            self.toast = nil
        }
    }
}
