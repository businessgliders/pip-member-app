import SwiftUI

struct WelcomeView: View {
    private enum Mode: String, CaseIterable { case signIn = "Sign in", signUp = "Create account" }
    private enum Field: Hashable { case firstName, lastName, email, password }

    @Environment(AuthStore.self) private var auth
    @State private var mode: Mode = .signIn
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isWorking: Bool = false
    @State private var errorText: String?
    @State private var infoText: String?
    @State private var hasAppeared: Bool = false
    @FocusState private var focused: Field?
    @Namespace private var segment
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 46

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    brand
                    headline
                    modePicker
                    form
                    messages
                    Button(action: submit) {
                        if isWorking {
                            ProgressView().tint(Theme.onPink)
                        } else {
                            Text(mode == .signIn ? "Sign in" : "Create account")
                        }
                    }
                    .buttonStyle(PillButtonStyle())
                    .disabled(!canSubmit || isWorking)

                    Button {} label: {
                        Label("Continue with phone · Coming soon", systemImage: "iphone")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .disabled(true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.05)) { hasAppeared = true }
        }
        .sensoryFeedback(.selection, trigger: mode)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ReformerIcon()
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                .frame(width: 40, height: 20)
            Text("Pilates in Pink")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            Text("Brampton")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.caramel)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your reformer\nis waiting.")
                .font(.system(size: headlineSize, weight: .heavy))
                .tracking(-1.6)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Book your class and choose your exact spot in the room.")
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(.top, 28)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 16)
    }

    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(Mode.allCases, id: \.self) { item in
                Button {
                    withAnimation(Theme.spring) {
                        mode = item
                        errorText = nil
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(mode == item ? Theme.ink : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            if mode == item {
                                Capsule()
                                    .fill(Theme.card)
                                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                                    .matchedGeometryEffect(id: "segment", in: segment)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.blush, in: Capsule())
    }

    private var form: some View {
        VStack(spacing: 14) {
            if mode == .signUp {
                HStack(spacing: 12) {
                    field("First name", text: $firstName, field: .firstName, content: .givenName)
                    field("Last name", text: $lastName, field: .lastName, content: .familyName)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            field("Email", text: $email, field: .email, content: .emailAddress, keyboard: .emailAddress)
            secureField
        }
        .cardStyle(padding: 16)
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        field: Field,
        content: UITextContentType,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            TextField("", text: text)
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(field == .email ? .never : .words)
                .autocorrectionDisabled()
                .focused($focused, equals: field)
                .submitLabel(.next)
                .onSubmit { advance(from: field) }
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(focused == field ? Theme.pink : Color.clear, lineWidth: 1.5)
                )
                .foregroundStyle(Theme.ink)
                .accessibilityLabel(title)
        }
    }

    private var secureField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.secondaryText)
            SecureField("", text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .padding(.horizontal, 14)
                .frame(height: 50)
                .background(Theme.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(focused == .password ? Theme.pink : Color.clear, lineWidth: 1.5)
                )
                .foregroundStyle(Theme.ink)
                .accessibilityLabel("Password")
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let errorText {
            Label(errorText, systemImage: "sparkle")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.caramelSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
        }
        if let infoText {
            Label(infoText, systemImage: "envelope.open")
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.blush, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
        }
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSubmit: Bool {
        let base = !trimmedEmail.isEmpty && !password.isEmpty
        if mode == .signUp {
            return base
                && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
                && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return base
    }

    private func advance(from field: Field) {
        switch field {
        case .firstName: focused = .lastName
        case .lastName: focused = .email
        case .email: focused = .password
        case .password: submit()
        }
    }

    private func submit() {
        guard canSubmit, !isWorking else { return }
        focused = nil
        errorText = nil
        infoText = nil
        isWorking = true
        Task {
            do {
                if mode == .signIn {
                    try await auth.signIn(email: trimmedEmail, password: password)
                } else {
                    let hasSession = try await auth.signUp(
                        firstName: firstName.trimmingCharacters(in: .whitespaces),
                        lastName: lastName.trimmingCharacters(in: .whitespaces),
                        email: trimmedEmail,
                        password: password
                    )
                    if !hasSession {
                        withAnimation(Theme.spring) {
                            infoText = "Check your inbox to confirm your email, then sign in here."
                            mode = .signIn
                        }
                    }
                }
            } catch {
                withAnimation(Theme.spring) { errorText = FriendlyError.fromAuth(error) }
            }
            isWorking = false
        }
    }
}
