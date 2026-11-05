import Foundation
import Observation

enum TimeOfDay: String, CaseIterable, Hashable {
    case morning = "Morning", afternoon = "Afternoon", evening = "Evening"

    static func of(_ date: Date) -> TimeOfDay {
        let hour = StudioTime.calendar.component(.hour, from: date)
        if hour < 12 { return .morning }
        if hour < 17 { return .afternoon }
        return .evening
    }
}

/// Client-side filters over `get_schedule` results.
struct ClassFilters: Equatable {
    var families: Set<ClassFamily> = []
    var instructors: Set<String> = []
    var levels: Set<String> = []
    var times: Set<TimeOfDay> = []

    var count: Int { families.count + instructors.count + levels.count + times.count }
    var isEmpty: Bool { count == 0 }

    func matches(_ s: ScheduleSession) -> Bool {
        if !families.isEmpty, !(s.family.map { families.contains($0) } ?? false) { return false }
        if !instructors.isEmpty, !instructors.contains(s.instructorName ?? "") { return false }
        if !levels.isEmpty, !levels.contains(s.classLevel ?? "") { return false }
        if !times.isEmpty, !times.contains(TimeOfDay.of(s.startDate)) { return false }
        return true
    }

    /// Short labels for the active chips row.
    var labels: [String] {
        families.map(\.displayName).sorted()
            + instructors.sorted()
            + levels.sorted()
            + TimeOfDay.allCases.filter { times.contains($0) }.map(\.rawValue)
    }
}

@Observable
final class ScheduleViewModel {
    private(set) var weekStartDay: Int = 0
    private(set) var horizonDays: Int = 14
    private(set) var selectedDay: Date
    private(set) var weekStart: Date
    private(set) var sessions: [ScheduleSession] = []
    private(set) var loadedWeek: Date?
    private(set) var error: FriendlyError?
    var filters = ClassFilters()

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

    /// "November 2026"
    var monthTitle: String { StudioTime.format(selectedDay, "MMMM yyyy") }

    var sessionsForSelectedDay: [ScheduleSession] {
        sessions
            .filter { StudioTime.isSameDay($0.startDate, selectedDay) }
            .sorted { $0.startDate < $1.startDate }
    }

    var filteredSessionsForSelectedDay: [ScheduleSession] {
        sessionsForSelectedDay.filter { filters.matches($0) }
    }

    // Options shown in the filter sheet (from what's loaded, plus current selections).
    var familyOptions: [ClassFamily] {
        let present = Set(sessions.compactMap(\.family)).union(filters.families)
        return ClassFamily.allCases.filter { present.contains($0) || present.isEmpty }
    }

    var instructorOptions: [String] {
        Set(sessions.compactMap { $0.instructorName }.filter { !$0.isEmpty }).union(filters.instructors).sorted()
    }

    var levelOptions: [String] {
        Set(sessions.compactMap { $0.classLevel }.filter { !$0.isEmpty }).union(filters.levels).sorted()
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
