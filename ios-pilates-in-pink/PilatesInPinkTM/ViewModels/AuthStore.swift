import Foundation
import Observation
import Supabase

/// Owns auth state. The root view switches signed-in / signed-out only from `authStateChanges`.
@Observable
final class AuthStore {
    enum Phase: Equatable { case loading, signedOut, signedIn }

    private(set) var phase: Phase = .loading
    private(set) var user: User?
    private var listener: Task<Void, Never>?

    init() {
        listener = Task { [weak self] in
            for await change in SupabaseService.client.auth.authStateChanges {
                guard let self else { return }
                self.apply(session: change.session)
            }
        }
    }

    private func apply(session: Session?) {
        if let session, !session.isExpired {
            user = session.user
            phase = .signedIn
        } else {
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
    func signUp(firstName: String, lastName: String, email: String, password: String) async throws -> Bool {
        let response = try await SupabaseService.client.auth.signUp(
            email: email,
            password: password,
            data: [
                "first_name": .string(firstName),
                "last_name": .string(lastName)
            ]
        )
        return response.session != nil
    }

    func signOut() async {
        do {
            try await SupabaseService.client.auth.signOut()
        } catch {
            print("Sign out failed: \(error.localizedDescription)")
        }
    }
}
