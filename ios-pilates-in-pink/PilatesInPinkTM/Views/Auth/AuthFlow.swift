import Foundation
import Observation
import SwiftUI

/// State for the full-screen, phone-first sign-in: phone → code, or email + password,
/// or email code, or create account. Holds no rules — Supabase decides everything.
@Observable
final class AuthFlow {
    enum Step: Hashable { case phone, email, code, create }

    enum Destination: Equatable {
        case phone(String)  // E.164
        case email(String)
    }

    struct Notice: Equatable {
        let kind: AuthNotice.Kind
        let text: String
    }

    private(set) var step: Step = .phone
    private var history: [Step] = []

    // Fields
    var phoneDigits = ""
    var email = ""
    var password = ""
    var code = ""
    var firstName = ""
    var lastName = ""
    var newPassword = ""
    var agreesToTerms = false
    var wantsMarketing = false

    // Status
    private(set) var isWorking = false
    private(set) var notice: Notice?
    private(set) var destination: Destination?
    /// Bumped on a wrong code so the boxes shake.
    private(set) var wrongCodeCount = 0
    /// When the next code may be requested.
    private(set) var resendAvailableAt = Date()
    var calm = false

    // MARK: Derived

    /// "+14165550123" from the digits typed (10 digits, or 11 starting with 1).
    var e164: String? {
        let digits = phoneDigits.filter { $0.isASCII && $0.isNumber }
        if digits.count == 10 { return "+1" + digits }
        if digits.count == 11, digits.hasPrefix("1") { return "+" + digits }
        return nil
    }

    var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    var isEmailValid: Bool { Self.isEmail(trimmedEmail) }
    var canSignIn: Bool { isEmailValid && !password.isEmpty }

    var canCreate: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && isEmailValid && newPassword.count >= 6 && agreesToTerms
    }

    static func isEmail(_ text: String) -> Bool {
        text.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil
    }

    /// "(416) 555-0123" as the member types.
    static func formatLocal(_ raw: String) -> String {
        var digits = raw.filter { $0.isASCII && $0.isNumber }
        if digits.count == 11, digits.hasPrefix("1") { digits.removeFirst() }
        digits = String(digits.prefix(10))
        let d = Array(digits)
        switch d.count {
        case 0: return ""
        case 1...3: return "(" + String(d)
        case 4...6: return "(\(String(d[0..<3]))) \(String(d[3...]))"
        default: return "(\(String(d[0..<3]))) \(String(d[3..<6]))-\(String(d[6...]))"
        }
    }

    /// "Sent to +1 (416) 555-0123" / "Sent to name@example.com".
    var destinationText: String {
        switch destination {
        case .phone(let phone):
            let local = String(phone.dropFirst(2))
            return "+1 " + Self.formatLocal(local)
        case .email(let email): return email
        case nil: return ""
        }
    }

    // MARK: Navigation

    private func animate(_ changes: () -> Void) {
        withAnimation(Motion.choose(Motion.authStep, calm: calm), changes)
    }

    private func setNotice(_ new: Notice?) {
        withAnimation(Motion.choose(Motion.fade, calm: calm)) { notice = new }
    }

    func go(_ next: Step, keepNotice: Bool = false) {
        guard next != step else { return }
        animate {
            history.append(step)
            step = next
            if !keepNotice { notice = nil }
        }
    }

    var canGoBack: Bool { !history.isEmpty }

    func back() {
        guard let previous = history.popLast() else { return }
        animate {
            step = previous
            notice = nil
        }
    }

    /// "Use email instead" / "Use phone number instead": a sideways switch, not a push.
    func switchTo(_ next: Step) {
        animate {
            history.removeAll()
            step = next
            notice = nil
        }
    }

    func startCreate() {
        go(.create)
    }

    // MARK: A. Phone

    func sendPhoneCode(auth: AuthStore, isResend: Bool = false) async {
        guard let phone = e164, !isWorking else {
            if e164 == nil { setNotice(Notice(kind: .error, text: "That number looks incomplete — include the area code.")) }
            return
        }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            try await auth.sendPhoneCode(phone: phone)
            codeSent(to: .phone(phone), isResend: isResend)
        } catch {
            if error is URLError {
                setNotice(Notice(kind: .error, text: FriendlyError.fromAuth(error)))
            } else {
                // The SMS provider isn't ready yet: carry on with email.
                print("Phone code failed: \(error.localizedDescription)")
                animate {
                    history.removeAll()
                    step = .email
                    notice = Notice(kind: .info, text: "Text codes are almost ready — use your email for now")
                }
            }
        }
    }

    // MARK: A2. Email

    func signIn(auth: AuthStore) async {
        guard !isWorking else { return }
        guard isEmailValid else {
            setNotice(Notice(kind: .error, text: "That email looks incomplete — check it and try again."))
            return
        }
        guard !password.isEmpty else {
            setNotice(Notice(kind: .error, text: "Enter your password, or email yourself a code instead."))
            return
        }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            try await auth.signIn(email: trimmedEmail, password: password)
            // Auth flips to signed in and the root takes over.
        } catch {
            let lower = error.localizedDescription.lowercased()
            if lower.contains("invalid login") || lower.contains("invalid credentials") {
                setNotice(Notice(kind: .error, text: "That password doesn't match — try again or reset it."))
            } else {
                setNotice(Notice(kind: .error, text: FriendlyError.fromAuth(error)))
            }
        }
    }

    func sendEmailCode(auth: AuthStore, isResend: Bool = false) async {
        guard !isWorking else { return }
        guard isEmailValid else {
            setNotice(Notice(kind: .error, text: "Enter your email first, then we'll send a code."))
            return
        }
        let target = trimmedEmail
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            try await auth.sendEmailCode(email: target)
            codeSent(to: .email(target), isResend: isResend)
        } catch {
            let lower = error.localizedDescription.lowercased()
            if lower.contains("signups not allowed") || lower.contains("not found") || lower.contains("otp_disabled") {
                setNotice(Notice(kind: .error, text: "We couldn't find an account for that email — create one below."))
            } else {
                setNotice(Notice(kind: .error, text: FriendlyError.fromAuth(error)))
            }
        }
    }

    func sendReset(auth: AuthStore) async {
        guard !isWorking else { return }
        guard isEmailValid else {
            setNotice(Notice(kind: .error, text: "Enter your email first, then tap Forgot password."))
            return
        }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            try await auth.resetPassword(email: trimmedEmail)
            setNotice(Notice(kind: .info, text: "Check your inbox — we've sent a link to reset your password."))
        } catch {
            setNotice(Notice(kind: .error, text: FriendlyError.fromAuth(error)))
        }
    }

    // MARK: B. Code

    private func codeSent(to target: Destination, isResend: Bool) {
        destination = target
        code = ""
        resendAvailableAt = Date().addingTimeInterval(TimeInterval(Motion.codeResendSeconds))
        if step != .code { go(.code) }
        if isResend { setNotice(Notice(kind: .info, text: "We've sent a new code.")) }
    }

    func resend(auth: AuthStore) async {
        switch destination {
        case .phone: await sendPhoneCode(auth: auth, isResend: true)
        case .email: await sendEmailCode(auth: auth, isResend: true)
        case nil: break
        }
    }

    func sanitizeCode() {
        let digits = String(code.filter { $0.isASCII && $0.isNumber }.prefix(6))
        if digits != code { code = digits }
    }

    func verify(auth: AuthStore) async {
        guard code.count == 6, let destination, !isWorking else { return }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            switch destination {
            case .phone(let phone): try await auth.verifyPhoneCode(phone: phone, code: code)
            case .email(let email): try await auth.verifyEmailCode(email: email, code: code)
            }
        } catch {
            if error is URLError {
                setNotice(Notice(kind: .error, text: FriendlyError.fromAuth(error)))
            } else if error.localizedDescription.lowercased().contains("expired") {
                setNotice(Notice(kind: .error, text: "That code has expired — send a new one."))
            } else {
                setNotice(Notice(kind: .error, text: "That code didn't match — try again"))
            }
            wrongCodeCount += 1
            code = ""
        }
    }

    // MARK: C. Create account (from "New here?")

    func createAccount(auth: AuthStore) async {
        guard !isWorking else { return }
        guard canCreate else {
            if !agreesToTerms {
                setNotice(Notice(kind: .error, text: "Please agree to the Terms and Privacy Policy to continue."))
            } else if newPassword.count < 6 {
                setNotice(Notice(kind: .error, text: "Try a longer password — at least 8 characters."))
            }
            return
        }
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last = lastName.trimmingCharacters(in: .whitespaces)
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            // The names and marketing choice are saved to the profile as soon as there's a
            // session, and onboarding picks up at the photo step.
            OnboardingHandoff.pending = OnboardingHandoff.Pending(
                firstName: first, lastName: last, marketing: wantsMarketing
            )
            let hasSession = try await auth.signUp(firstName: first, lastName: last, email: trimmedEmail, password: newPassword)
            if !hasSession {
                animate {
                    password = ""
                    history.removeAll()
                    step = .email
                    notice = Notice(kind: .info, text: "Check your inbox to confirm your email, then sign in.")
                }
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    if step != .create { newPassword = "" }
                }
            }
        } catch {
            OnboardingHandoff.pending = nil
            setNotice(Notice(kind: .error, text: FriendlyError.fromAuth(error)))
        }
    }
}

/// Carries the create-account details across the switch from signed-out to signed-in.
enum OnboardingHandoff {
    struct Pending: Equatable {
        let firstName: String
        let lastName: String
        let marketing: Bool
    }

    @MainActor static var pending: Pending?
}
