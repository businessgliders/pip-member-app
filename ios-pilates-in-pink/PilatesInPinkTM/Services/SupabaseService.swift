import Foundation
import Supabase

/// Studio-wide constants. The publishable key is safe to ship in the client.
nonisolated enum StudioConstants {
    static let supabaseURL = URL(string: "https://ouckdjvsxozksskinkzf.supabase.co")!
    static let publishableKey = "sb_publishable_lWYfvJy52Edv2IONcibzRg_8KfJOvTG"
    static let organizationId = "25c31fca-264f-4756-b804-817a3a1cbc50"
    static let locationId = "0cf87cd1-31fa-4a16-9ac8-f3df06ce4981"
}

/// Shared Supabase client using the SDK's built-in session storage with auto refresh.
nonisolated enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: StudioConstants.supabaseURL,
        supabaseKey: StudioConstants.publishableKey,
        options: SupabaseClientOptions(
            auth: .init(autoRefreshToken: true, emitLocalSessionAsInitialSession: true)
        )
    )
}
