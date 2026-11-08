import SwiftUI

/// One quiet glass panel on the welcome video. Collapsed it's just the cream GET STARTED pill;
/// expanded it holds the sign-in steps and create account, cross-fading in place while
/// the panel's height eases to fit.
struct SignInPanel: View {
    @Bindable var flow: SignInFlow

    private enum Field: Hashable { case identifier, password, code, firstName, lastName, email, newPassword }

    @Environment(AuthStore.self) private var auth
    @Environment(\.calmMotion) private var calm
    @FocusState private var focus: Field?
    @State private var showsPassword = false
    /// Focus for the UIKit new-password field, which sits outside `@FocusState`.
    @State private var newPasswordFocused = false
    @Namespace private var morph

    private let secondary = Color.white.opacity(0.7)

    var body: some View {
        VStack(spacing: 0) {
            if flow.isExpanded {
                expanded
                    .transition(.opacity)
            } else {
                Button { flow.expand() } label: { Text("Get started") }
                    .buttonStyle(CreamPillButtonStyle())
                    .matchedGeometryEffect(id: "primary", in: morph)
                    .accessibilityHint("Sign in or create an account")
                    .transition(.opacity)
            }
        }
        .padding(flow.isExpanded ? 20 : 0)
        .background { chrome.opacity(flow.isExpanded ? 1 : 0) }
        .environment(\.colorScheme, .dark) // dark keyboard and controls over the video
        .simultaneousGesture(swipeToCollapse)
        .accessibilityAction(.escape) { flow.back() }
        .onChange(of: flow.isExpanded) { _, expanded in
            if expanded {
                focusSoon(after: Motion.standard)
            } else {
                focus = nil
                newPasswordFocused = false
            }
        }
        .onChange(of: flow.step) { _, _ in
            showsPassword = false
            newPasswordFocused = false
            focusSoon(after: Motion.short)
        }
        .onChange(of: focus) { _, value in
            if value != nil { newPasswordFocused = false }
        }
        .onChange(of: flow.code) { _, _ in
            flow.sanitizeCode()
            if flow.code.count == 6 { run { await flow.verifyCode(auth: auth) } }
        }
    }

    // MARK: Chrome

    private var chrome: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Theme.fixedInk.opacity(0.3))
        }
        .overlay(shape.strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        .contentShape(shape)
        .onTapGesture {} // taps on the panel never reach the video behind it
    }

    private var swipeToCollapse: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dy = value.translation.height
                guard flow.isExpanded, dy > 70, dy > abs(value.translation.width) * 1.5 else { return }
                flow.collapse()
            }
    }

    // MARK: Expanded

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ZStack(alignment: .top) {
                switch flow.step {
                case .identify: identifyStep.transition(.opacity)
                case .code: codeStep.transition(.opacity)
                case .create: createStep.transition(.opacity)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Button { flow.back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, -12)
            .accessibilityLabel(flow.step == .identify ? "Close" : "Back")

            Text(title)
                .font(Typo.font(22, .light, relativeTo: .title2))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
        }
        .padding(.top, -8)
        .padding(.bottom, -4)
    }

    private var title: String {
        switch flow.step {
        case .identify: "Sign in or join"
        case .code: "Enter your code"
        case .create: "Create your account"
        }
    }

    // MARK: Step 1 — email + password, or phone

    private var identifyStep: some View {
        VStack(spacing: 12) {
            VStack(spacing: flow.showsPasswordField ? 12 : 0) {
                identifierField
                    .matchedGeometryEffect(id: "field", in: morph)
                inlinePassword
            }
            .animation(Motion.choose(Motion.welcomePanel, calm: calm), value: flow.showsPasswordField)
            if flow.primaryAction == .textCode {
                Text("We'll text a 6-digit code to this number.")
                    .font(Typo.secondary)
                    .foregroundStyle(secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .transition(.opacity)
            }
            noticeLine
            primaryButton(primaryLabel, enabled: flow.canSubmitIdentifier) { submitIdentifier() }
            if flow.showsPasswordField {
                VStack(spacing: 0) {
                    Button("Email me a code instead") { run { await flow.sendEmailCode(auth: auth) } }
                        .buttonStyle(PanelTextButtonStyle())
                    Button("Forgot password?") { run { await flow.sendReset(auth: auth) } }
                        .buttonStyle(PanelTextButtonStyle())
                }
                .disabled(flow.isWorking)
                .transition(.opacity)
            }
            linkButton(lead: "New here? ", action: "Create an account") { flow.goToCreate() }
        }
        .animation(Motion.choose(Motion.fade, calm: calm), value: flow.primaryAction)
    }

    private var primaryLabel: String {
        switch flow.primaryAction {
        case .signIn: "Sign in"
        case .textCode: "Text me a code"
        case .proceed: "Continue"
        }
    }

    private func submitIdentifier() {
        run {
            if await flow.submitIdentifier(auth: auth) { focus = .password }
        }
    }

    /// Always in the hierarchy so iOS Passwords can fill email and password together from one
    /// pick; collapsed to nothing (and out of reach of touch and VoiceOver) until it's needed.
    private var inlinePassword: some View {
        let visible = flow.showsPasswordField
        return passwordField(text: $flow.password, field: .password, content: .password, submit: .go) {
            submitIdentifier()
        }
        .frame(height: visible ? nil : 1, alignment: .top)
        .clipped()
        .opacity(visible ? 1 : 0.011)
        .allowsHitTesting(visible)
        .accessibilityHidden(!visible)
    }

    private var identifierField: some View {
        fieldBox(focused: focus == .identifier) {
                HStack(spacing: 10) {
                    TextField("", text: $flow.identifier, prompt: prompt("Email or phone number"))
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .identifier)
                        .submitLabel(flow.primaryAction == .signIn ? .next : .continue)
                        .onSubmit {
                            if flow.primaryAction == .signIn, flow.password.isEmpty {
                                focus = .password
                            } else {
                                submitIdentifier()
                            }
                        }
                        .accessibilityLabel("Email or phone number")
                    if let icon = identityIcon {
                        Image(systemName: icon)
                            .font(.system(size: 15))
                            .foregroundStyle(secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .accessibilityHidden(true)
                    }
                }
                .animation(Motion.fade, value: identityIcon)
            }
    }

    private var identityIcon: String? {
        switch flow.identity {
        case .email, .partialEmail: "envelope"
        case .phone, .partialPhone: "phone"
        default: nil
        }
    }

    // MARK: Code

    private var codeStep: some View {
        VStack(spacing: 12) {
            Text("Enter the 6-digit code we sent to \(SignInFlow.display(flow.codeIdentity))")
                .font(Typo.secondary)
                .foregroundStyle(secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            fieldBox(focused: focus == .code) {
                TextField("", text: $flow.code, prompt: prompt("6-digit code"))
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .font(Typo.font(22, .regular, relativeTo: .title3).monospacedDigit())
                    .tracking(6)
                    .focused($focus, equals: .code)
                    .submitLabel(.done)
                    .onSubmit { run { await flow.verifyCode(auth: auth) } }
                    .accessibilityLabel("Six-digit code")
            }
            .matchedGeometryEffect(id: "field", in: morph)
            noticeLine
            primaryButton("Verify", enabled: flow.code.count == 6) {
                run { await flow.verifyCode(auth: auth) }
            }
            Button("Send a new code") { run { await flow.resendCode(auth: auth) } }
                .buttonStyle(PanelTextButtonStyle())
                .disabled(flow.isWorking)
        }
    }

    // MARK: Create account

    private var createStep: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                textField("First name", text: $flow.firstName, field: .firstName, content: .givenName, capitalization: .words) {
                    focus = .lastName
                }
                textField("Last name", text: $flow.lastName, field: .lastName, content: .familyName, capitalization: .words) {
                    focus = .email
                }
            }
            textField("Email", text: $flow.newEmail, field: .email, content: .username, keyboard: .emailAddress) {
                focus = nil
                newPasswordFocused = true
            }
            .matchedGeometryEffect(id: "field", in: morph)
            newPasswordBox
            noticeLine
            primaryButton("Create account", enabled: flow.canCreate) {
                run { await flow.createAccount(auth: auth) }
            }
            Text(Self.legalText)
                .font(Typo.font(12, .regular, relativeTo: .caption))
                .foregroundStyle(secondary)
                .tint(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }

    private static let legalText: AttributedString = {
        var text = (try? AttributedString(
            markdown: "By continuing you agree to our [Terms](\(LegalLinks.terms.absoluteString)) and [Privacy Policy](\(LegalLinks.privacy.absoluteString))"
        )) ?? AttributedString("By continuing you agree to our Terms and Privacy Policy")
        for run in text.runs where run.link != nil {
            text[run.range].underlineStyle = .single
            text[run.range].foregroundColor = .white
        }
        return text
    }()

    // MARK: Pieces

    private func prompt(_ text: String) -> Text {
        Text(text).foregroundStyle(Color.white.opacity(0.55))
    }

    private func fieldBox<Content: View>(focused: Bool, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return content()
            .font(Typo.body)
            .foregroundStyle(.white)
            .tint(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Color.white.opacity(0.12), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(focused ? 0.4 : 0), lineWidth: 1))
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
        content: UITextContentType,
        submit: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        fieldBox(focused: focus == field) {
            HStack(spacing: 8) {
                Group {
                    if showsPassword {
                        TextField("", text: text, prompt: prompt("Password"))
                    } else {
                        SecureField("", text: text, prompt: prompt("Password"))
                    }
                }
                .textContentType(content)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: field)
                .submitLabel(submit)
                .onSubmit(onSubmit)
                .accessibilityLabel("Password")

                Button {
                    showsPassword.toggle()
                    Task { focus = field }
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundStyle(secondary)
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

    /// New password with the studio's rules, so a suggested strong password always qualifies.
    private var newPasswordBox: some View {
        fieldBox(focused: newPasswordFocused) {
            HStack(spacing: 8) {
                NewPasswordField(
                    text: $flow.newPassword,
                    isFocused: $newPasswordFocused,
                    revealed: showsPassword
                ) {
                    run { await flow.createAccount(auth: auth) }
                }
                .frame(minHeight: 44)

                Button {
                    showsPassword.toggle()
                    newPasswordFocused = true
                } label: {
                    Image(systemName: showsPassword ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundStyle(secondary)
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
                Text(label).opacity(flow.isWorking ? 0 : 1)
                if flow.isWorking { ProgressView().tint(Theme.fixedInk) }
            }
        }
        .buttonStyle(CreamPillButtonStyle())
        .disabled(!enabled || flow.isWorking)
        .matchedGeometryEffect(id: "primary", in: morph)
        .padding(.top, 2)
    }

    private func linkButton(lead: String, action label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("\(Text(lead).foregroundStyle(secondary))\(Text(label).foregroundStyle(.white).underline())")
                .font(Typo.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private var noticeLine: some View {
        if let notice = flow.notice {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                switch notice {
                case .error(let text):
                    Circle()
                        .fill(Theme.softPink)
                        .frame(width: 6, height: 6)
                        .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                    Text(text)
                case .info(let text):
                    Image(systemName: "envelope.open").font(.system(size: 13))
                    Text(text)
                }
            }
            .font(Typo.secondary)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .transition(Motion.rise(calm: calm))
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Helpers

    private func run(_ work: @escaping () async -> Void) {
        Task { await work() }
    }

    private func focusSoon(after delay: Double) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            guard flow.isExpanded else { return }
            switch flow.step {
            case .identify: focus = .identifier
            case .code: focus = .code
            case .create:
                if flow.firstName.isEmpty {
                    focus = .firstName
                } else {
                    focus = nil
                    newPasswordFocused = true
                }
            }
        }
    }
}

/// Quiet underlined white text button inside the glass panel.
struct PanelTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typo.font(15, .regular, relativeTo: .callout))
            .foregroundStyle(.white)
            .underline(true, color: .white.opacity(0.4))
            .frame(maxWidth: .infinity, minHeight: 40)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}
