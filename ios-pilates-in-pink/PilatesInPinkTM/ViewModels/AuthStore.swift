import Foundation
import Observation
import Supabase

/// Owns auth state. The root view switches signed-in / signed-out only from `authStateChanges`.
@Observable
final class AuthStore {
    enum Phase: Equatable { case loading, signedOut, signedIn }

    private(set) var phase: Phase = .loading
    private(set) var user: User?
    /// True when this signed-in phase began with a sign-in on this screen (not a session
    /// restored at launch). Drives the onboarding check and the finale.
    private(set) var isFreshSignIn = false
    private var listener: Task<Void, Never>?

    init() {
        listener = Task { [weak self] in
            for await change in SupabaseService.client.auth.authStateChanges {
                guard let self else { return }
                self.apply(session: change.session, event: change.event)
            }
        }
    }

    private func apply(session: Session?, event: AuthChangeEvent) {
        if let session, !session.isExpired {
            if phase != .signedIn || user?.id != session.user.id {
                // A refreshed token on launch is a restored session, not a sign-in.
                isFreshSignIn = event == .signedIn
            }
            user = session.user
            phase = .signedIn
        } else {
            isFreshSignIn = false
            user = nil
            phase = .signedOut
        }
    }

    // MARK: Profile

    var firstName: String { metadataString("first_name") ?? "" }
    var lastName: String { metadataString("last_name") ?? "" }
    var email: String { user?.email ?? "" }
    var userId: UUID? { user?.id }

    var displayName: String {
        let name = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
        return name.isEmpty ? "Member" : name
    }

    var initials: String {
        let letters = [firstName.first, lastName.first].compactMap { $0 }
        if letters.isEmpty, let e = email.first { return String(e).uppercased() }
        return String(letters).uppercased()
    }

    /// Name to show: the database profile first, then auth metadata, then the email's local part.
    func identity(with profile: MemberProfile?) -> MemberIdentity {
        MemberIdentity(profile: profile, metadataFirst: firstName, metadataLast: lastName, authEmail: email)
    }

    private func metadataString(_ key: String) -> String? {
        guard let value = user?.userMetadata[key] else { return nil }
        if case let .string(text) = value { return text }
        return nil
    }

    // MARK: Actions

    func signIn(email: String, password: String) async throws {
        try await SupabaseService.client.auth.signIn(email: email, password: password)
    }

    /// Returns true when a session was created immediately (no email confirmation needed).
    /// Names are collected in onboarding afterwards.
    func signUp(email: String, password: String) async throws -> Bool {
        let response = try await SupabaseService.client.auth.signUp(email: email, password: password)
        return response.session != nil
    }

    /// Emails a password-reset link.
    func resetPassword(email: String) async throws {
        try await SupabaseService.client.auth.resetPasswordForEmail(email)
    }

    // MARK: One-time codes

    /// Emails a 6-digit sign-in code to an existing member (never creates an account).
    func sendEmailCode(email: String) async throws {
        try await SupabaseService.client.auth.signInWithOTP(email: email, shouldCreateUser: false)
    }

    func verifyEmailCode(email: String, code: String) async throws {
        _ = try await SupabaseService.client.auth.verifyOTP(email: email, token: code, type: .email)
    }

    /// Texts a 6-digit sign-in code. `phone` is E.164 (+1…).
    func sendPhoneCode(phone: String) async throws {
        try await SupabaseService.client.auth.signInWithOTP(phone: phone)
    }

    func verifyPhoneCode(phone: String, code: String) async throws {
        _ = try await SupabaseService.client.auth.verifyOTP(phone: phone, token: code, type: .sms)
    }

    func signOut() async {
        do {
            try await SupabaseService.client.auth.signOut()
        } catch {
            print("Sign out failed: \(error.localizedDescription)")
        }
    }
}
