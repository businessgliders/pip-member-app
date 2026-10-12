import Foundation
import Supabase

/// User-facing error copy. Positive, never scolding, always with a next step.
struct FriendlyError: Identifiable, Equatable {
    enum Kind: Equatable {
        case stationTaken, outOfCredits, outsideWindow, alreadyBooked, classFull, waitlist, offline, auth, generic
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let message: String

    static func == (lhs: FriendlyError, rhs: FriendlyError) -> Bool { lhs.id == rhs.id }

    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        return false
    }

    /// Maps database / network errors to friendly copy.
    static func from(_ error: Error) -> FriendlyError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost, .cannotFindHost:
                return FriendlyError(
                    kind: .offline,
                    title: "You seem to be offline",
                    message: "Check your connection, then pull down to refresh."
                )
            default: break
            }
        }

        var text = error.localizedDescription
        if let pg = error as? PostgrestError {
            text = [pg.message, pg.detail ?? "", pg.hint ?? ""].joined(separator: " ")
        }
        let lower = text.lowercased()

        if lower.contains("credit") {
            return FriendlyError(
                kind: .outOfCredits,
                title: "You're out of credits",
                message: "Top up to book this class. Online purchases are coming soon — the front desk is happy to help in the meantime."
            )
        }
        if (lower.contains("station") || lower.contains("reformer"))
            && (lower.contains("taken") || lower.contains("unavailable") || lower.contains("occupied") || lower.contains("already") || lower.contains("not available")) {
            return FriendlyError(
                kind: .stationTaken,
                title: "That reformer was just taken",
                message: "Someone just grabbed that reformer — pick another."
            )
        }
        if lower.contains("waitlist") {
            return FriendlyError(
                kind: .waitlist,
                title: "Waitlist update",
                message: "We couldn't update your waitlist spot. Pull down to refresh and try again."
            )
        }
        if lower.contains("already") || lower.contains("duplicate") {
            return FriendlyError(
                kind: .alreadyBooked,
                title: "You're already in this class",
                message: "You already have a spot here — you'll find it in My Bookings."
            )
        }
        if lower.contains("full") || lower.contains("capacity") {
            return FriendlyError(
                kind: .classFull,
                title: "This class just filled up",
                message: "Join the waitlist and we'll hold your place in line, or pick another time."
            )
        }
        if lower.contains("window") || lower.contains("horizon") || lower.contains("advance")
            || lower.contains("not open") || lower.contains("too far") || lower.contains("started") || lower.contains("past") {
            return FriendlyError(
                kind: .outsideWindow,
                title: "Not open for booking right now",
                message: "This class is outside the booking window. Try another day on the schedule."
            )
        }
        return FriendlyError(
            kind: .generic,
            title: "That didn't go through",
            message: "Pull down to refresh and give it another try."
        )
    }

    /// Maps sign-in / sign-up errors to friendly copy.
    static func fromAuth(_ error: Error) -> String {
        let lower = error.localizedDescription.lowercased()
        if error is URLError {
            return "You seem to be offline. Check your connection and try again."
        }
        if lower.contains("invalid login") || lower.contains("invalid credentials") {
            return "That email and password don't match. Try again, or create an account."
        }
        if lower.contains("already registered") || lower.contains("already exists") {
            return "That email already has an account — sign in instead."
        }
        if lower.contains("not confirmed") {
            return "Almost there — confirm your email using the link in your inbox, then sign in."
        }
        if lower.contains("password") {
            return "Try a longer password — at least 6 characters."
        }
        if lower.contains("rate limit") || lower.contains("too many") {
            return "Lots of attempts — take a short breather and try again in a minute."
        }
        if lower.contains("email") {
            return "Double-check your email address and try again."
        }
        return "Something didn't go through. Please try again."
    }
}
