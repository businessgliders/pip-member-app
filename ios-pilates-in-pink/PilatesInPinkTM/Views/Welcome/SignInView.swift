import SwiftUI

/// Calm two-step sign-in on cream, pushed from the welcome video.
/// Step 1 asks for an email (phone comes later), step 2 for the password; create account
/// lives on the same screen. The logo stays still while the steps cross-fade and the
/// field and button morph in place.
struct SignInView: View {
    private enum Step { case identifier, password, create }
    private enum Field: Hashable { case identifier, password, firstName, lastName, email, newPassword }
    private enum Message: Equatable {
        case error(String)
        case info(String)
    }

    @Environment(AuthStore.self) private var auth
    @Environment(\.calmMotion) private var calm

    @State private var step: Step = .identifier
    @State private var identifier = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var newEmail = ""
    @State private var newPassword = ""
    @State private var showsPassword = false
    @State private var isWorking = false
    @State private var message: Message?
    @FocusState private var focus: Field?
    @Namespace private var morph

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Logo sits about a third of the way down the screen.
                    Color.clear.frame(height: max(16, proxy.size.height * 0.27 - 36))
                    LogoMark(size: 72)
                        .accessibilityElement()
                        .accessibilityLabel("Pilates in Pink")
                        .padding(.bottom, 28)

                    ZStack(alignment: .top) {
                        switch step {
                        case .identifier: identifierStep.transition(.opacity)
                        case .password: passwordStep.transition(.opacity)
                        case .create: createStep.transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
                .avoidingFold()
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: Steps

    private var identifierStep: some View {
        VStack(spacing: 14) {
            title("Sign in or join")
            fieldBox(focused: focus == .identifier) {
                TextField("", text: $identifier, prompt: prompt("Email or phone number"))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .identifier)
                    .submitLabel(.continue)
                    .onSubmit(continueFromIdentifier)
                    .accessibilityLabel("Email or phone number")
            }
            .matchedGeometryEffect(id: "field", in: morph)
            messageLine
            primaryButton("Continue", enabled: !trimmedIdentifier.isEmpty, action: continueFromIdentifier)
            Button {
                go(to: .create)
            } label: {
                Text("\(Text("New to Pilates in Pink™? ").foregroundStyle(Theme.secondaryText))\(Text("Create an account").foregroundStyle(Theme.ink).underline())")
                    .font(Typo.secondary)
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private var passwordStep: some View {
        VStack(spacing: 14) {
            title("Welcome back")
            emailChip
            // Lets iOS Passwords pair the saved email with the password field below.
            TextField("", text: .constant(trimmedIdentifier))
                .textContentType(.username)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            passwordField(text: $password, field: .password, placeholder: "Password", content: .password, submit: .go, onSubmit: signIn)
                .matchedGeometryEffect(id: "field", in: morph)
            messageLine
            primaryButton("Sign in", enabled: !password.isEmpty, action: signIn)
            Button("Forgot password?", action: sendReset)
                .buttonStyle(QuietButtonStyle())
                .disabled(isWorking)
        }
    }

    private var createStep: some View {
        VStack(spacing: 12) {
            title("Create your account")
            HStack(spacing: 12) {
                textField("First name", text: $firstName, field: .firstName, content: .givenName, capitalization: .words) { focus = .lastName }
                textField("Last name", text: $lastName, field: .lastName, content: .familyName, capitalization: .words) { focus = .email }
            }
            textField("Email", text: $newEmail, field: .email, content: .emailAddress, keyboard: .emailAddress) { focus = .newPassword }
                .matchedGeometryEffect(id: "field", in: morph)
            passwordField(text: $newPassword, field: .newPassword, placeholder: "Password", content: .newPassword, submit: .join, onSubmit: createAccount)
            messageLine
            primaryButton("Create account", enabled: canCreate, action: createAccount)
                .padding(.top, 2)
            Button {
                go(to: .identifier)
            } label: {
                Text("\(Text("Already a member? ").foregroundStyle(Theme.secondaryText))\(Text("Sign in").foregroundStyle(Theme.ink).underline())")
                    .font(Typo.secondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Pieces

    private func title(_ text: String) -> some View {
        Text(text)
            .font(Typo.font(26, .light, relativeTo: .title))
            .tracking(-0.3)
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.center)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
    }

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Theme.secondaryText)
    }

    private var emailChip: some View {
        HStack(spacing: 8) {
            Text(trimmedIdentifier)
                .font(Typo.font(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Button("Edit") { go(to: .identifier) }
                .font(Typo.font(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(Theme.ink)
                .underline()
                .buttonStyle(.plain)
                .frame(minHeight: 32)
                .accessibilityLabel("Edit email")
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(Theme.blush, in: Capsule())
        .padding(.bottom, 4)
    }

    private func fieldBox<Content: View>(focused: Bool, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return content()
            .font(Typo.body)
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Theme.card, in: shape)
            .overlay(shape.strokeBorder(focused ? Theme.ink.opacity(0.4) : Theme.hairline, lineWidth: 1))
            .animation(Motion.fade, value: focused)
    }

    private func textField(
        _ placeholder: String,
        text: Binding<String>,
        field: Field,
        content: UITextContentType,
        keyboard: UIKeyboardType = .default,
        capitalization: TextInputAutocapitalization = .never,
        onSubmit: @escaping () -> Void
    ) -> some View {
        fieldBox(focused: focus == field) {
            TextField("", text: text, prompt: prompt(placeholder))
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled()
                .focused($focus, equals: field)
                .submitLabel(.next)
                .onSubmit(onSubmit)
                .accessibilityLabel(placeholder)
        }
    }

    private func passwordField(
        text: Binding<String>,
        field: Field,
        placeholder: String,
        content: UITextContentType,
        submit: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        fieldBox(focused: focus == field) {
            HStack(spacing: 8) {
                Group {
                    if showsPassword {
                        TextField("", text: text, prompt: prompt(placeholder))
                    } else {
                        SecureField("", text: text, prompt: prompt(placeholder))
                    }
                }
                .textContentType(content)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: field)
                .submitLabel(submit)
                .onSubmit(onSubmit)
                .accessibilityLabel(placeholder)

                Button {
                    showsPassword.toggle()
                    Task { focus = field }
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .padding(.trailing, -10)
                .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
            }
        }
    }

    private func primaryButton(_ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(label).opacity(isWorking ? 0 : 1)
                if isWorking { ProgressView().tint(Theme.primaryLabel) }
            }
        }
        .buttonStyle(PillButtonStyle())
        .disabled(!enabled || isWorking)
        .matchedGeometryEffect(id: "button", in: morph)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var messageLine: some View {
        if let message {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                switch message {
                case .error(let text):
                    Circle().fill(Theme.pink).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    Text(text)
                case .info(let text):
                    Image(systemName: "envelope.open").font(.system(size: 13))
                    Text(text)
                }
            }
            .font(Typo.secondary)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .transition(Motion.rise(calm: calm))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Logic

    private var trimmedIdentifier: String { identifier.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canCreate: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && !newEmail.trimmingCharacters(in: .whitespaces).isEmpty
            && !newPassword.isEmpty
    }

    private static func isEmail(_ text: String) -> Bool {
        text.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil
    }

    private static func isPhone(_ text: String) -> Bool {
        let stripped = text.filter { !" -().+".contains($0) }
        return stripped.count >= 7 && stripped.allSatisfy(\.isNumber)
    }

    private func show(_ new: Message?) {
        withAnimation(Motion.choose(Motion.fade, calm: calm)) { message = new }
    }

    private func go(to next: Step) {
        if next == .create, newEmail.isEmpty, Self.isEmail(trimmedIdentifier) {
            newEmail = trimmedIdentifier
        }
        if next == .identifier { password = "" }
        showsPassword = false
        withAnimation(Motion.choose(Motion.signInStep, calm: calm)) {
            step = next
            message = nil
        }
        Task {
            try? await Task.sleep(for: .seconds(Motion.short))
            switch next {
            case .identifier: focus = .identifier
            case .password: focus = .password
            case .create: focus = firstName.isEmpty ? .firstName : .newPassword
            }
        }
    }

    private func continueFromIdentifier() {
        let value = trimmedIdentifier
        guard !value.isEmpty else { return }
        if Self.isEmail(value) {
            go(to: .password)
        } else if Self.isPhone(value) {
            show(.info("Phone sign-in is coming soon — please use your email for now."))
        } else {
            show(.error("That doesn't look like an email address — check it and try again."))
        }
    }

    private func signIn() {
        guard !password.isEmpty, !isWorking else { return }
        isWorking = true
        show(nil)
        Task {
            do {
                try await auth.signIn(email: trimmedIdentifier, password: password)
                // Auth state flips to signed in; the root cross-fades to Home.
            } catch {
                let lower = error.localizedDescription.lowercased()
                if lower.contains("invalid login") || lower.contains("invalid credentials") {
                    show(.error("That password doesn't match — try again or reset it."))
                } else {
                    show(.error(FriendlyError.fromAuth(error)))
                }
                focus = .password
            }
            isWorking = false
        }
    }

    private func sendReset() {
        guard !isWorking else { return }
        isWorking = true
        show(nil)
        Task {
            do {
                try await auth.resetPassword(email: trimmedIdentifier)
                show(.info("Check your inbox — we've sent a link to reset your password."))
            } catch {
                show(.error(FriendlyError.fromAuth(error)))
            }
            isWorking = false
        }
    }

    private func createAccount() {
        guard canCreate, !isWorking else { return }
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isEmail(email) else {
            show(.error("That doesn't look like an email address — check it and try again."))
            focus = .email
            return
        }
        isWorking = true
        focus = nil
        show(nil)
        Task {
            do {
                let hasSession = try await auth.signUp(
                    firstName: firstName.trimmingCharacters(in: .whitespaces),
                    lastName: lastName.trimmingCharacters(in: .whitespaces),
                    email: email,
                    password: newPassword
                )
                if !hasSession {
                    identifier = email
                    password = ""
                    withAnimation(Motion.choose(Motion.signInStep, calm: calm)) {
                        step = .password
                        message = .info("Check your inbox to confirm your email, then sign in here.")
                    }
                }
            } catch {
                show(.error(FriendlyError.fromAuth(error)))
            }
            isWorking = false
        }
    }
}
