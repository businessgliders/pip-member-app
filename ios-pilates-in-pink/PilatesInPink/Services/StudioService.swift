import Foundation
import Supabase

/// Thin wrapper around the studio's Supabase reads and RPCs.
/// Contains no business rules — the database enforces everything.
nonisolated struct StudioService: Sendable {
    private var client: SupabaseClient { SupabaseService.client }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }

    // MARK: Reads

    func schedule(from: Date, to: Date) async throws -> [ScheduleSession] {
        let params = ScheduleParams(
            p_location_id: StudioConstants.locationId,
            p_from: StudioTime.isoString(from),
            p_to: StudioTime.isoString(to)
        )
        let response = try await client.rpc("get_schedule", params: params).execute()
        return try decode([ScheduleSession].self, from: response.data)
    }

    func takenStations(sessionId: String) async throws -> [TakenStation] {
        let response = try await client
            .rpc("get_taken_stations", params: SessionParams(p_session_id: sessionId))
            .execute()
        return try decode([TakenStation].self, from: response.data)
    }

    func stations() async throws -> [Station] {
        let response = try await client
            .from("stations")
            .select("id, number, row_num, col_num, is_active")
            .eq("location_id", value: StudioConstants.locationId)
            .execute()
        return try decode([Station].self, from: response.data)
    }

    func settings() async throws -> StudioSettings {
        let response = try await client
            .from("studio_settings")
            .select("member_booking_horizon_days, week_start_day, cancellation_window_minutes")
            .eq("location_id", value: StudioConstants.locationId)
            .single()
            .execute()
        return try decode(StudioSettings.self, from: response.data)
    }

    func credits() async throws -> Credits? {
        let response = try await client
            .rpc("get_my_credits", params: OrganizationParams(p_organization_id: StudioConstants.organizationId))
            .execute()
        if let rows = try? decode([Credits].self, from: response.data) {
            return rows.first
        }
        return try decode(Credits.self, from: response.data)
    }

    func bookings() async throws -> [Booking] {
        let response = try await client
            .from("bookings")
            .select("id, status, station_id, class_session_id, booked_at, class_sessions(starts_at, ends_at, class_types(name, level))")
            .eq("status", value: "booked")
            .execute()
        let rows = try decode([Booking].self, from: response.data)
        return rows.sorted { $0.startDate < $1.startDate }
    }

    // MARK: Writes (RPC only)

    func bookClass(sessionId: String, stationId: String) async throws {
        _ = try await client
            .rpc("book_class", params: BookParams(p_session_id: sessionId, p_station_id: stationId))
            .execute()
    }

    /// Returns the resulting status: "cancelled" or "late_cancelled".
    func cancelBooking(bookingId: String) async throws -> String {
        let response = try await client
            .rpc("cancel_booking", params: CancelParams(p_booking_id: bookingId, p_waive_penalty: false))
            .execute()
        if let status = try? decode(String.self, from: response.data) {
            return status
        }
        let raw = String(data: response.data, encoding: .utf8) ?? ""
        return raw.trimmingCharacters(in: CharacterSet(charactersIn: "\"[]{} \n"))
    }

    func changeReformer(bookingId: String, stationId: String) async throws {
        _ = try await client
            .rpc("change_reformer", params: ChangeParams(p_booking_id: bookingId, p_station_id: stationId))
            .execute()
    }

    func joinWaitlist(sessionId: String) async throws {
        _ = try await client
            .rpc("join_waitlist", params: WaitlistParams(p_session_id: sessionId))
            .execute()
    }

    func leaveWaitlist(entryId: String) async throws {
        _ = try await client
            .rpc("leave_waitlist", params: LeaveWaitlistParams(p_entry_id: entryId))
            .execute()
    }
}

/// Runs an async throwing operation and captures its outcome, so reads can run concurrently.
nonisolated func captureResult<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> Result<T, any Error> {
    do {
        return .success(try await operation())
    } catch {
        return .failure(error)
    }
}

// MARK: - RPC params

nonisolated private struct ScheduleParams: Encodable, Sendable {
    let p_location_id: String
    let p_from: String
    let p_to: String
}

nonisolated private struct SessionParams: Encodable, Sendable {
    let p_session_id: String
}

nonisolated private struct OrganizationParams: Encodable, Sendable {
    let p_organization_id: String
}

nonisolated private struct BookParams: Encodable, Sendable {
    let p_session_id: String
    let p_station_id: String

    enum CodingKeys: String, CodingKey { case p_session_id, p_station_id, p_profile_id }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_session_id, forKey: .p_session_id)
        try c.encode(p_station_id, forKey: .p_station_id)
        try c.encodeNil(forKey: .p_profile_id)
    }
}

nonisolated private struct CancelParams: Encodable, Sendable {
    let p_booking_id: String
    let p_waive_penalty: Bool
}

nonisolated private struct ChangeParams: Encodable, Sendable {
    let p_booking_id: String
    let p_station_id: String
}

nonisolated private struct WaitlistParams: Encodable, Sendable {
    let p_session_id: String

    enum CodingKeys: String, CodingKey { case p_session_id, p_profile_id }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_session_id, forKey: .p_session_id)
        try c.encodeNil(forKey: .p_profile_id)
    }
}

nonisolated private struct LeaveWaitlistParams: Encodable, Sendable {
    let p_entry_id: String
}
