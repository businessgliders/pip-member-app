import Foundation
import Observation

/// Shared member data: studio settings, reformers, credits and bookings.
@Observable
final class StudioStore {
    private(set) var settings: StudioSettings?
    private(set) var stations: [Station] = []
    private(set) var credits: Credits?
    private(set) var bookings: [Booking] = []
    private(set) var hasLoadedBookings = false
    private(set) var hasLoadedCredits = false
    private(set) var bookingsError: FriendlyError?
    private(set) var creditsError: FriendlyError?
    /// Bumped after any booking action so the schedule reloads.
    private(set) var scheduleVersion = 0

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
    }

    /// Loads everything besides the schedule, concurrently.
    func refreshAll() async {
        let service = self.service
        async let settingsResult = captureResult { try await service.settings() }
        async let stationsResult = captureResult { try await service.stations() }
        async let creditsResult = captureResult { try await service.credits() }
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

        switch await bookingsResult {
        case .success(let value):
            bookings = value
            bookingsError = nil
        case .failure(let error):
            if !FriendlyError.isCancellation(error) { bookingsError = FriendlyError.from(error) }
        }
        hasLoadedBookings = true
    }

    /// Call after any write (success or failure) to keep every screen in sync.
    func afterMutation() async {
        scheduleVersion += 1
        await refreshBookings()
        await refreshCredits()
    }
}
