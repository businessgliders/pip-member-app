import Foundation
import Observation

@Observable
final class ScheduleViewModel {
    private(set) var weekStartDay: Int = 0
    private(set) var horizonDays: Int = 14
    private(set) var selectedDay: Date
    private(set) var weekStart: Date
    private(set) var sessions: [ScheduleSession] = []
    private(set) var loadedWeek: Date?
    private(set) var error: FriendlyError?

    private var requestID = 0
    private let service = StudioService()

    init() {
        let today = StudioTime.startOfDay(Date())
        selectedDay = today
        weekStart = StudioTime.startOfWeek(containing: today, weekStartDay: 0)
    }

    var today: Date { StudioTime.startOfDay(Date()) }
    var lastBookableDay: Date { StudioTime.addDays(horizonDays, to: today) }
    var days: [Date] { (0..<7).map { StudioTime.addDays($0, to: weekStart) } }
    var canGoBack: Bool { weekStart > StudioTime.startOfWeek(containing: today, weekStartDay: weekStartDay) }
    var canGoForward: Bool { StudioTime.addDays(7, to: weekStart) <= lastBookableDay }
    var isShowingSkeleton: Bool { loadedWeek != weekStart }

    var sessionsForSelectedDay: [ScheduleSession] {
        sessions
            .filter { StudioTime.isSameDay($0.startDate, selectedDay) }
            .sorted { $0.startDate < $1.startDate }
    }

    func isSelectable(_ day: Date) -> Bool {
        day >= today && day <= lastBookableDay
    }

    func configure(with settings: StudioSettings?) {
        weekStartDay = settings?.weekStartDay ?? 0
        horizonDays = settings?.memberBookingHorizonDays ?? 14
        weekStart = StudioTime.startOfWeek(containing: selectedDay, weekStartDay: weekStartDay)
    }

    func select(_ day: Date) {
        guard isSelectable(day) else { return }
        selectedDay = day
    }

    func selectToday() {
        selectedDay = today
        weekStart = StudioTime.startOfWeek(containing: today, weekStartDay: weekStartDay)
    }

    func shiftWeek(by delta: Int) async {
        guard delta < 0 ? canGoBack : canGoForward else { return }
        weekStart = StudioTime.addDays(7 * delta, to: weekStart)
        if let first = days.first(where: { isSelectable($0) }) {
            selectedDay = first
        }
        await load()
    }

    func load() async {
        requestID += 1
        let id = requestID
        let week = weekStart
        let service = self.service
        let end = StudioTime.addDays(7, to: week)
        let result = await captureResult { try await service.schedule(from: week, to: end) }
        guard id == requestID else { return }

        switch result {
        case .success(let rows):
            sessions = rows
            error = nil
            loadedWeek = week
        case .failure(let err):
            if FriendlyError.isCancellation(err) { return }
            if loadedWeek != week { sessions = [] }
            error = FriendlyError.from(err)
            loadedWeek = week
        }
    }
}
