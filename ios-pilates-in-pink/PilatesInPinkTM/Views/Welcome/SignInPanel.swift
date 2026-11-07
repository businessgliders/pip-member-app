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
            }
        }
        .onChange(of: flow.step) { _, _ in
            showsPassword = false
            focusSoon(after: Motion.short)
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
                case .verify: verifyStep.transition(.opacity)
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
        case .verify: flow.primaryMethod == .smsCode ? "Sign in with your phone" : "Welcome back"
        case .code: "Enter your code"
        case .create: "Create your account"
        }
    }

    // MARK: Step 1 — who are you

    private var identifyStep: some View {
        VStack(spacing: 12) {
            fieldBox(focused: focus == .identifier) {
                HStack(spacing: 10) {
                    TextField("", text: $flow.identifier, prompt: prompt("Email or phone number"))
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .identifier)
                        .submitLabel(.continue)
                        .onSubmit { flow.continueFromIdentifier() }
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
            .matchedGeometryEffect(id: "field", in: morph)
            noticeLine
            primaryButton("Continue", enabled: flow.identity != .empty) {
                flow.continueFromIdentifier()
            }
            linkButton(lead: "New here? ", action: "Create an account") { flow.goToCreate() }
        }
    }

    private var identityIcon: String? {
        switch flow.identity {
        case .email, .partialEmail: "envelope"
        case .phone, .partialPhone: "phone"
        default: nil
        }
    }

    // MARK: Step 2 — prove it's you

    private var verifyStep: some View {
        VStack(spacing: 12) {
            identityChip(SignInFlow.display(flow.identity))
            switch flow.primaryMethod {
            case .password: passwordMethod
            case .smsCode, .emailCode: smsMethod
            }
            ForEach(flow.alternativeMethods, id: \.self) { method in
                alternative(method)
            }
            if flow.primaryMethod == .password {
                Button("Forgot password?") { run { await flow.sendReset(auth: auth) } }
                    .buttonStyle(PanelTextButtonStyle())
                    .disabled(flow.isWorking)
            }
            linkButton(lead: "No account? ", action: "Create one") { flow.goToCreate() }
        }
    }

    @ViewBuilder
    private var passwordMethod: some View {
        // Lets iOS Passwords pair the saved email with the password below.
        TextField("", text: .constant(SignInFlow.display(flow.identity)))
            .textContentType(.username)
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        passwordField(text: $flow.password, field: .password, content: .password, submit: .go) {
            run { await flow.signIn(auth: auth) }
        }
        .matchedGeometryEffect(id: "field", in: morph)
        noticeLine
        primaryButton("Sign in", enabled: !flow.password.isEmpty) {
            run { await flow.signIn(auth: auth) }
        }
    }

    @ViewBuilder
    private var smsMethod: some View {
        Text("We'll text a 6-digit code to this number.")
            .font(Typo.secondary)
            .foregroundStyle(secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        noticeLine
        primaryButton("Text me a code", enabled: true) {
            run { await flow.sendPhoneCode(auth: auth) }
        }
    }

    @ViewBuilder
    private func alternative(_ method: SignInFlow.Method) -> some View {
        switch method {
        case .emailCode:
            Button("Email me a code instead") { run { await flow.sendEmailCode(auth: auth) } }
                .buttonStyle(PanelTextButtonStyle())
                .disabled(flow.isWorking)
        case .password, .smsCode:
            EmptyView()
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
                focus = .newPassword
            }
            .matchedGeometryEffect(id: "field", in: morph)
            passwordField(text: $flow.newPassword, field: .newPassword, content: .newPassword, submit: .join) {
                run { await flow.createAccount(auth: auth) }
            }
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

    private func identityChip(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(Typo.font(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            Button("Edit") { flow.editIdentifier() }
                .font(Typo.font(14, .medium, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .underline()
                .buttonStyle(.plain)
                .frame(minHeight: 32)
                .accessibilityLabel("Edit \(text)")
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 2)
        .background(Color.white.opacity(0.14), in: Capsule())
        .frame(maxWidth: .infinity, alignment: .leading)
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
            case .verify: focus = flow.primaryMethod == .password ? .password : nil
            case .code: focus = .code
            case .create: focus = flow.firstName.isEmpty ? .firstName : .newPassword
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
