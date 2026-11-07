import Foundation
import Observation

/// Shared member data: studio settings, reformers, credits and bookings.
@Observable
final class StudioStore {
    private(set) var settings: StudioSettings?
    private(set) var stations: [Station] = []
    private(set) var credits: Credits?
    /// The member's database profile (name + member id); nil until loaded.
    private(set) var profile: MemberProfile?
    private(set) var hasLoadedProfile = false
    private(set) var bookings: [Booking] = []
    private(set) var hasLoadedBookings = false
    private(set) var hasLoadedCredits = false
    private(set) var bookingsError: FriendlyError?
    private(set) var creditsError: FriendlyError?
    /// Bumped after any booking action so the schedule reloads.
    private(set) var scheduleVersion = 0
    /// Class type id → description ("What to Expect").
    private(set) var classDescriptions: [String: String] = [:]
    private var hasLoadedClassTypes = false
    /// Schedule rows covering upcoming bookings, keyed by session id (for instructor, family, etc).
    private(set) var bookingSessions: [String: ScheduleSession] = [:]

    private let service = StudioService()

    var upcomingBookings: [Booking] {
        let now = Date()
        return bookings.filter { $0.endDate > now }.sorted { $0.startDate < $1.startDate }
    }

    var nextBooking: Booking? { upcomingBookings.first }

    func stationNumber(for stationId: String?) -> Int? {
        guard let stationId else { return nil }
        return stations.first { $0.id == stationId }?.number
    }

    func description(forClassType id: String?) -> String? {
        guard let id, let text = classDescriptions[id]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        return text
    }

    func session(for booking: Booking) -> ScheduleSession? {
        bookingSessions[booking.classSessionId]
    }

    func loadClassTypesIfNeeded() async {
        guard !hasLoadedClassTypes else { return }
        do {
            let rows = try await service.classTypes()
            var map: [String: String] = [:]
            for row in rows { if let d = row.description { map[row.id] = d } }
            classDescriptions = map
            hasLoadedClassTypes = true
        } catch {
            print("Class types load failed: \(error.localizedDescription)")
        }
    }

    /// Fetches schedule rows across the upcoming bookings' range so reservation rows can show instructors.
    func refreshBookingSessions() async {
        let upcoming = upcomingBookings
        guard let first = upcoming.first, let last = upcoming.last else {
            bookingSessions = [:]
            return
        }
        let from = StudioTime.startOfDay(first.startDate)
        let to = StudioTime.addDays(1, to: StudioTime.startOfDay(last.startDate))
        let service = self.service
        let result = await captureResult { try await service.schedule(from: from, to: to) }
        if case .success(let rows) = result {
            var map: [String: ScheduleSession] = [:]
            for row in rows { map[row.sessionId] = row }
            bookingSessions = map
        }
    }

    // MARK: Visits

    /// Booked classes this calendar month that have already started.
    var visitDaysThisMonth: Set<Int> {
        let cal = StudioTime.calendar
        let now = Date()
        let days = bookings
            .filter { cal.isDate($0.startDate, equalTo: now, toGranularity: .month) && $0.startDate <= now }
            .map { cal.component(.day, from: $0.startDate) }
        return Set(days)
    }

    var classesThisMonth: Int {
        let cal = StudioTime.calendar
        let now = Date()
        return bookings.filter { cal.isDate($0.startDate, equalTo: now, toGranularity: .month) && $0.startDate <= now }.count
    }

    func loadSettingsIfNeeded() async {
        guard settings == nil else { return }
        do {
            settings = try await service.settings()
        } catch {
            print("Settings load failed: \(error.localizedDescription)")
        }
    }

    func loadStationsIfNeeded() async {
        guard stations.isEmpty else { return }
        do {
            stations = try await service.stations()
        } catch {
            print("Stations load failed: \(error.localizedDescription)")
        }
    }

    /// Re-reads the room layout (row/column come from the database), keeping the current
    /// layout if the request fails.
    func refreshStations() async {
        do {
            let value = try await service.stations()
            if value != stations { stations = value }
        } catch {
            print("Stations refresh failed: \(error.localizedDescription)")
        }
    }

    /// Keeps the last good profile if the request fails.
    func refreshProfile() async {
        let service = self.service
        let result = await captureResult { try await service.profile() }
        switch result {
        case .success(let value):
            if let value { profile = value }
        case .failure(let error):
            if !FriendlyError.isCancellation(error) {
                print("Profile load failed: \(error.localizedDescription)")
            }
        }
        hasLoadedProfile = true
    }

    func refreshCredits() async {
        let service = self.service
        let result = await captureResult { try await service.credits() }
        switch result {
        case .success(let value):
            credits = value
            creditsError = nil
        case .failure(let error):
            if !FriendlyError.isCancellation(error) { creditsError = FriendlyError.from(error) }
        }
        hasLoadedCredits = true
    }

    func refreshBookings() async {
        let service = self.service
        let result = await captureResult { try await service.bookings() }
        switch result {
        case .success(let value):
            bookings = value
            bookingsError = nil
        case .failure(let error):
            if !FriendlyError.isCancellation(error) { bookingsError = FriendlyError.from(error) }
        }
        hasLoadedBookings = true
        await refreshBookingSessions()
    }

    /// Loads everything besides the schedule, concurrently.
    func refreshAll() async {
        let service = self.service
        async let settingsResult = captureResult { try await service.settings() }
        async let stationsResult = captureResult { try await service.stations() }
        async let creditsResult = captureResult { try await service.credits() }
        async let profileResult = captureResult { try await service.profile() }
        async let bookingsResult = captureResult { try await service.bookings() }

        if case .success(let value) = await settingsResult { settings = value }
        if case .success(let value) = await stationsResult { stations = value }

        switch await creditsResult {
        case .success(let value):
            credits = value
            creditsError = nil
        case .failure(let error):
            if !FriendlyError.isCancellation(error) { creditsError = FriendlyError.from(error) }
        }
        hasLoadedCredits = true

        switch await profileResult {
        case .success(let value):
            if let value { profile = value }
        case .failure(let error):
            if !FriendlyError.isCancellation(error) {
                print("Profile load failed: \(error.localizedDescription)")
            }
        }
        hasLoadedProfile = true

        switch await bookingsResult {
        case .success(let value):
            bookings = value
            bookingsError = nil
        case .failure(let error):
            if !FriendlyError.isCancellation(error) { bookingsError = FriendlyError.from(error) }
        }
        hasLoadedBookings = true
        await refreshBookingSessions()
    }

    /// Call after any write (success or failure) to keep every screen in sync.
    func afterMutation() async {
        scheduleVersion += 1
        await refreshBookings()
        await refreshCredits()
    }
}
