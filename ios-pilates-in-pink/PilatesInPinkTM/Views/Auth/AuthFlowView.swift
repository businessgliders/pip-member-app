import SwiftUI

/// Full-screen sign-in, opened from the welcome screen's LOG IN OR SIGN UP pill.
/// A. phone → B. code; A2. email + password (or an email code, or a reset link);
/// C. create account. Once signed in, the root takes over (onboarding or Home).
struct AuthFlowView: View {
    let onClose: () -> Void

    @Environment(AuthStore.self) private var auth
    @Environment(\.calmMotion) private var calm
    @State private var flow = AuthFlow()
    @State private var safariLink: SafariLink?
    @State private var newPasswordFocused = false
    @FocusState private var focus: Field?
    @FocusState private var codeFocused: Bool

    private enum Field: Hashable { case phone, email, password, newEmail }

    /// The focused field, from focus state (nil = keyboard down).
    private var focusKey: String? {
        if codeFocused { return "code" }
        if newPasswordFocused { return "newPassword" }
        if let focus { return "\(focus)" }
        return nil
    }

    var body: some View {
        ZStack {
            AuthBackdrop()
            VStack(spacing: 0) {
                AuthHeader(onClose: close)
                ZStack {
                    switch flow.step {
                    case .phone: phoneStep.transition(.authStep(calm: calm))
                    case .email: emailStep.transition(.authStep(calm: calm))
                    case .code: codeStep.transition(.authStep(calm: calm))
                    case .create: createStep.transition(.authStep(calm: calm))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .environment(\.colorScheme, .dark)
        .environment(\.openURL, OpenURLAction { url in
            safariLink = SafariLink(url: url)
            return .handled
        })
        .safariSheet($safariLink)
        .onAppear { flow.calm = calm }
        .onChange(of: calm) { _, new in flow.calm = new }
        .task(id: flow.step) { await focusCurrentStep() }
    }

    private func close() {
        focus = nil
        codeFocused = false
        newPasswordFocused = false
        onClose()
    }

    private func focusCurrentStep() async {
        try? await Task.sleep(for: .seconds(Motion.short))
        switch flow.step {
        case .phone: focus = .phone
        case .email: focus = flow.trimmedEmail.isEmpty ? .email : .password
        case .code:
            focus = nil
            codeFocused = true
        case .create: focus = flow.trimmedEmail.isEmpty ? .newEmail : nil
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        Task { await work() }
    }

    @ViewBuilder
    private var noticeView: some View {
        if let notice = flow.notice {
            AuthNotice(kind: notice.kind, text: notice.text)
                .padding(.top, 12)
                .transition(Motion.rise(calm: calm))
        }
    }

    private var workingLabel: some View {
        ProgressView().tint(Theme.fixedInk)
    }

    // MARK: A. Phone

    private var phoneStep: some View {
        AuthFormStep(focusKey: focusKey) {
            AuthTitle(text: "what's your number?")
            HStack(spacing: 12) {
                AuthFieldBox {
                    Text("+1 🇨🇦")
                        .font(Typo.font(17, .medium, relativeTo: .body))
                        .fixedSize()
                }
                .accessibilityLabel("Country code plus 1, Canada")
                AuthFieldBox(isFocused: focus == .phone) {
                    TextField("", text: phoneBinding, prompt: authPrompt("(416) 555-0123"))
                        .textContentType(.telephoneNumber)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .phone)
                        .accessibilityLabel("Mobile number")
                }
            }
            .padding(.top, 28)
            AuthFootnote(text: "We'll text you a 6-digit code. Message and data rates may apply.")
                .padding(.top, 8)
            noticeView
            Button {
                run { await flow.sendPhoneCode(auth: auth) }
            } label: {
                if flow.isWorking { workingLabel } else { Text("CONTINUE") }
            }
            .buttonStyle(CreamPillButtonStyle())
            .disabled(flow.e164 == nil || flow.isWorking)
            .authPrimaryAnchor()
            .padding(.top, 20)
            AuthLinks {
                Button("Use email instead") { flow.switchTo(.email) }
            }
        }
    }

    /// Shows "(416) 555-0123" while keeping just the digits; strips a leading 1 from autofill.
    private var phoneBinding: Binding<String> {
        Binding {
            AuthFlow.formatLocal(flow.phoneDigits)
        } set: { new in
            var digits = new.filter { $0.isASCII && $0.isNumber }
            if digits.count == 11, digits.hasPrefix("1") { digits.removeFirst() }
            flow.phoneDigits = String(digits.prefix(10))
        }
    }

    // MARK: A2. Email

    private var emailStep: some View {
        AuthFormStep(focusKey: focusKey) {
            AuthTitle(text: "what's your email?")
            VStack(spacing: 12) {
                AuthFieldBox(isFocused: focus == .email) {
                    TextField("", text: $flow.email, prompt: authPrompt("Email"))
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .email)
                        .onSubmit { focus = .password }
                }
                AuthFieldBox(isFocused: focus == .password) {
                    SecureField("", text: $flow.password, prompt: authPrompt("Password"))
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focus, equals: .password)
                        .onSubmit { run { await flow.signIn(auth: auth) } }
                }
            }
            .padding(.top, 28)
            Button("Forgot password?") { run { await flow.sendReset(auth: auth) } }
                .buttonStyle(CreamSmallLinkButtonStyle())
                .disabled(flow.isWorking)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
            noticeView
            Button {
                run { await flow.signIn(auth: auth) }
            } label: {
                if flow.isWorking { workingLabel } else { Text("SIGN IN") }
            }
            .buttonStyle(CreamPillButtonStyle())
            .disabled(!flow.canSignIn || flow.isWorking)
            .authPrimaryAnchor()
            .padding(.top, 16)
            AuthLinks {
                Button("Email me a code instead") { run { await flow.sendEmailCode(auth: auth) } }
                    .disabled(flow.isWorking)
                Button("Use phone number instead") { flow.switchTo(.phone) }
                Button("New here? Create an account") { flow.startCreate() }
            }
        }
    }

    // MARK: B. Code

    private var codeStep: some View {
        AuthFormStep(focusKey: focusKey) {
            AuthTitle(text: "enter your code")
            HStack(spacing: 6) {
                Text("Sent to \(flow.destinationText)")
                    .font(Typo.font(16, .regular, relativeTo: .body))
                    .foregroundStyle(Theme.cream.opacity(0.72))
                Button("Edit") { flow.back() }
                    .font(Typo.font(16, .medium, relativeTo: .body))
                    .foregroundStyle(Theme.cream)
                    .underline(true, color: Theme.cream.opacity(0.35))
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
            }
            .padding(.top, 6)
            CodeBoxes(code: $flow.code, focus: $codeFocused, shakes: flow.wrongCodeCount) {
                run { await flow.verify(auth: auth) }
            }
            .padding(.top, 24)
            .opacity(flow.isWorking ? 0.6 : 1)
            noticeView
            ResendCountdown(availableAt: flow.resendAvailableAt) {
                run { await flow.resend(auth: auth) }
            }
            .disabled(flow.isWorking)
            .authPrimaryAnchor()
            .padding(.top, 20)
        }
    }

    // MARK: C. Create account

    private var createStep: some View {
        AuthFormStep(focusKey: focusKey) {
            AuthTitle(text: "create your account")
            VStack(spacing: 12) {
                AuthFieldBox(isFocused: focus == .newEmail) {
                    TextField("", text: $flow.email, prompt: authPrompt("Email"))
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focus, equals: .newEmail)
                        .onSubmit {
                            focus = nil
                            newPasswordFocused = true
                        }
                }
                AuthFieldBox(isFocused: newPasswordFocused) {
                    NewPasswordField(
                        text: $flow.newPassword,
                        isFocused: $newPasswordFocused,
                        revealed: false,
                        placeholder: "Create a password"
                    ) {
                        newPasswordFocused = false
                        run { await flow.createAccount(auth: auth) }
                    }
                    .frame(height: 24)
                }
            }
            .padding(.top, 28)
            AuthCheckRow(isOn: $flow.agreesToTerms, label: termsAgreementText,
                         accessibilityText: "I agree to the Terms and Privacy Policy")
                .padding(.top, 16)
            noticeView
            Button {
                newPasswordFocused = false
                run { await flow.createAccount(auth: auth) }
            } label: {
                if flow.isWorking { workingLabel } else { Text("CREATE ACCOUNT") }
            }
            .buttonStyle(CreamPillButtonStyle())
            .disabled(!flow.canCreate || flow.isWorking)
            .authPrimaryAnchor()
            .padding(.top, 20)
            AuthLinks {
                Button("I already have an account") { flow.back() }
            }
        }
    }
}

/// "Resend code in 30s", counting down, then a link.
struct ResendCountdown: View {
    let availableAt: Date
    let onResend: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = Int(ceil(availableAt.timeIntervalSince(context.date)))
            if remaining > 0 {
                Text("Resend code in \(remaining)s")
                    .font(Typo.font(15, .regular, relativeTo: .callout))
                    .monospacedDigit()
                    .foregroundStyle(Theme.cream.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentTransition(.numericText(countsDown: true))
            } else {
                Button("Resend code", action: onResend)
                    .buttonStyle(CreamLinkButtonStyle())
            }
        }
    }
}
