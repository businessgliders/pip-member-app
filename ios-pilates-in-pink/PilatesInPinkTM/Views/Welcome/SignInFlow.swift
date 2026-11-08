import Foundation
import Observation
import SwiftUI

/// State and logic for the sign-in / register panel on the welcome video.
/// Lives above the layout, so resizing between the one- and two-column layouts keeps
/// everything the member has typed and the step they're on.
@Observable
final class SignInFlow {
    /// Email + password happen together on `.identify`; one-time codes get their own step.
    enum Step: Hashable { case identify, code, create }

    enum Notice: Equatable {
        case error(String)
        case info(String)
    }

    /// What the member typed on step 1, detected live.
    enum Identity: Equatable {
        case empty
        case email(String)
        case partialEmail
        /// E.164, e.g. +14165550100.
        case phone(String)
        case partialPhone
        case unknown
    }

    /// What the main button on step 1 does right now.
    enum PrimaryAction: Equatable { case signIn, textCode, proceed }

    // Panel
    var isExpanded = false
    private(set) var stack: [Step] = [.identify]
    var step: Step { stack.last ?? .identify }

    // Fields
    var identifier = ""
    var password = ""
    var code = ""
    var firstName = ""
    var lastName = ""
    var newEmail = ""
    var newPassword = ""

    // Status
    private(set) var isWorking = false
    private(set) var notice: Notice?
    /// Where the current one-time code was sent.
    private(set) var codeIdentity: Identity?
    /// Set from the view: Reduce Motion / Low Power turn every change into a short cross-fade.
    var calm = false

    // MARK: Derived

    var identity: Identity { Self.parse(identifier) }

    /// The password field shows as soon as it looks like an email — or iOS has filled it.
    var showsPasswordField: Bool {
        identifier.contains("@") || !password.isEmpty
    }

    var primaryAction: PrimaryAction {
        switch identity {
        case .phone, .partialPhone: return .textCode
        default: return showsPasswordField ? .signIn : .proceed
        }
    }

    /// Whether the main button on step 1 can be pressed. Autofill only ever enables it.
    var canSubmitIdentifier: Bool {
        switch primaryAction {
        case .signIn: if case .email = identity { return !password.isEmpty } else { return false }
        case .textCode: if case .phone = identity { return true } else { return false }
        case .proceed: return identity != .empty
        }
    }

    var canCreate: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !newEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && !newPassword.isEmpty
    }

    static func parse(_ raw: String) -> Identity {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .empty }
        if text.contains("@") {
            return isEmail(text) ? .email(text.lowercased()) : .partialEmail
        }
        let allowed = CharacterSet(charactersIn: "+ -().").union(CharacterSet(charactersIn: "0123456789"))
        guard text.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return .unknown }
        let digits = text.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return .unknown }
        if text.hasPrefix("+") {
            return (8...15).contains(digits.count) ? .phone("+" + digits) : .partialPhone
        }
        if digits.count == 10 { return .phone("+1" + digits) }
        if digits.count == 11, digits.hasPrefix("1") { return .phone("+" + digits) }
        return .partialPhone
    }

    static func isEmail(_ text: String) -> Bool {
        text.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil
    }

    /// "+14165550100" → "+1 (416) 555-0100"; emails as typed.
    static func display(_ identity: Identity?) -> String {
        switch identity {
        case .email(let email): return email
        case .phone(let phone):
            let digits = phone.dropFirst()
            if phone.hasPrefix("+1"), digits.count == 11 {
                let d = Array(digits.dropFirst())
                return "+1 (\(String(d[0..<3]))) \(String(d[3..<6]))-\(String(d[6..<10]))"
            }
            return phone
        default: return ""
        }
    }

    // MARK: Navigation

    private func animate(_ changes: () -> Void) {
        withAnimation(Motion.choose(Motion.welcomePanel, calm: calm), changes)
    }

    private func setNotice(_ new: Notice?) {
        withAnimation(Motion.choose(Motion.fade, calm: calm)) { notice = new }
    }

    func expand() {
        animate { isExpanded = true }
    }

    /// Back to the GET STARTED pill; everything typed is kept.
    func collapse() {
        guard isExpanded else { return }
        animate { isExpanded = false }
    }

    private func push(_ next: Step) {
        animate {
            stack.append(next)
            notice = nil
        }
    }

    /// One step back; collapses from step 1.
    func back() {
        guard stack.count > 1 else {
            collapse()
            return
        }
        animate {
            stack.removeLast()
            notice = nil
        }
    }

    func goToCreate() {
        if newEmail.isEmpty, case .email(let email) = identity { newEmail = email }
        push(.create)
    }

    // MARK: Step 1

    /// The main button / return key on step 1. Returns `true` when the password is still
    /// missing, so the view can move focus to it.
    @discardableResult
    func submitIdentifier(auth: AuthStore) async -> Bool {
        switch identity {
        case .email:
            if password.isEmpty { return true }
            await signIn(auth: auth)
        case .phone:
            await sendPhoneCode(auth: auth)
        default:
            showIdentifierProblem()
        }
        return false
    }

    private func showIdentifierProblem() {
        switch identity {
        case .email, .phone:
            break
        case .empty:
            setNotice(.error("Enter your email or mobile number to continue."))
        case .partialEmail:
            setNotice(.error("That email looks incomplete — check it and try again."))
        case .partialPhone:
            setNotice(.error("That number looks incomplete — include the area code."))
        case .unknown:
            setNotice(.error("Enter an email address or a mobile number."))
        }
    }

    // MARK: Sign in

    func signIn(auth: AuthStore) async {
        guard case .email(let email) = identity, !password.isEmpty, !isWorking else { return }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            try await auth.signIn(email: email, password: password)
            // Auth state flips to signed in; the root cross-fades to Home. The fields stay
            // filled until the panel is gone, so iOS can offer to save the password.
        } catch {
            let lower = error.localizedDescription.lowercased()
            if lower.contains("invalid login") || lower.contains("invalid credentials") {
                setNotice(.error("That password doesn't match — try again or reset it."))
            } else {
                setNotice(.error(FriendlyError.fromAuth(error)))
            }
        }
    }

    func sendEmailCode(auth: AuthStore, isResend: Bool = false) async {
        let target = isResend ? (codeIdentity ?? identity) : identity
        guard !isWorking else { return }
        guard case .email(let email) = target else {
            showIdentifierProblem()
            return
        }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            try await auth.sendEmailCode(email: email)
            codeIdentity = target
            code = ""
            if step != .code { push(.code) }
            if isResend { setNotice(.info("We've sent a new code.")) }
        } catch {
            let lower = error.localizedDescription.lowercased()
            if lower.contains("signups not allowed") || lower.contains("not found") || lower.contains("otp_disabled") {
                setNotice(.error("We couldn't find an account for that email — create one instead."))
            } else {
                setNotice(.error(FriendlyError.fromAuth(error)))
            }
        }
    }

    func sendPhoneCode(auth: AuthStore, isResend: Bool = false) async {
        let target = isResend ? (codeIdentity ?? identity) : identity
        guard case .phone(let phone) = target, !isWorking else { return }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            try await auth.sendPhoneCode(phone: phone)
            codeIdentity = target
            code = ""
            if step != .code { push(.code) }
            if isResend { setNotice(.info("We've sent a new code.")) }
        } catch {
            if error is URLError {
                setNotice(.error(FriendlyError.fromAuth(error)))
            } else {
                // Phone sign-in isn't switched on in the backend yet.
                setNotice(.info("Phone sign-in is almost ready — please use your email for now."))
            }
        }
    }

    func resendCode(auth: AuthStore) async {
        switch codeIdentity {
        case .phone: await sendPhoneCode(auth: auth, isResend: true)
        default: await sendEmailCode(auth: auth, isResend: true)
        }
    }

    func sendReset(auth: AuthStore) async {
        guard !isWorking else { return }
        guard case .email(let email) = identity else {
            showIdentifierProblem()
            return
        }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            try await auth.resetPassword(email: email)
            setNotice(.info("Check your inbox — we've sent a link to reset your password."))
        } catch {
            setNotice(.error(FriendlyError.fromAuth(error)))
        }
    }

    // MARK: Code

    /// Keeps the code to six digits.
    func sanitizeCode() {
        let digits = String(code.filter { $0.isASCII && $0.isNumber }.prefix(6))
        if digits != code { code = digits }
    }

    func verifyCode(auth: AuthStore) async {
        guard code.count == 6, let codeIdentity, !isWorking else { return }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            switch codeIdentity {
            case .email(let email): try await auth.verifyEmailCode(email: email, code: code)
            case .phone(let phone): try await auth.verifyPhoneCode(phone: phone, code: code)
            default: return
            }
        } catch {
            let lower = error.localizedDescription.lowercased()
            if error is URLError {
                setNotice(.error(FriendlyError.fromAuth(error)))
            } else if lower.contains("expired") {
                setNotice(.error("That code has expired — send a new one."))
            } else {
                setNotice(.error("That code didn't work — check it or send a new one."))
            }
            code = ""
        }
    }

    // MARK: Create account

    func createAccount(auth: AuthStore) async {
        guard canCreate, !isWorking else { return }
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isEmail(email) else {
            setNotice(.error("That email looks incomplete — check it and try again."))
            return
        }
        isWorking = true
        setNotice(nil)
        defer { isWorking = false }
        do {
            let hasSession = try await auth.signUp(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                email: email,
                password: newPassword
            )
            if !hasSession {
                animate {
                    identifier = email
                    password = ""
                    stack = [.identify]
                    notice = .info("Check your inbox to confirm your email, then sign in.")
                }
                // The new password leaves the screen still filled in, so iOS can offer to save
                // it; only then is it cleared. It's never stored by the app.
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    if step != .create { newPassword = "" }
                }
            }
        } catch {
            setNotice(.error(FriendlyError.fromAuth(error)))
        }
    }
}

/// Placeholder legal links — replace with the real pages.
enum LegalLinks {
    static let terms = URL(string: "https://www.pilatesinpinkstudio.com")!
    static let privacy = URL(string: "https://www.pilatesinpinkstudio.com")!
}
