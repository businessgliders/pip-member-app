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

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    hero(height: max(340, proxy.size.height * 0.46), topInset: proxy.safeAreaInsets.top)
                    sheet
                        .padding(.top, -Theme.sheetRadius)
                        .frame(minHeight: proxy.size.height * 0.54 + proxy.safeAreaInsets.bottom, alignment: .top)
                }
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(.container, edges: .top)
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.1)) { hasAppeared = true }
        }
        .sensoryFeedback(.selection, trigger: mode)
    }

    // MARK: Hero

    private func hero(height: CGFloat, topInset: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            StudioPhoto(name: "signin_bg", tone: .deep, fadeIn: true)
            LinearGradient(
                colors: [Color.black.opacity(0.3), .clear, Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading) {
                Wordmark(color: .white, markSize: 30, textSize: 17)
                    .padding(.top, topInset + 12)
                Spacer()
                Text("Your reformer\nis waiting.")
                    .font(Typo.font(42, .light, relativeTo: .largeTitle))
                    .tracking(-0.8)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)
                    .accessibilityAddTraits(.isHeader)
                Text("Book your class and choose your exact spot in the room.")
                    .font(Typo.font(16, .regular, relativeTo: .body))
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.top, 6)
                    .opacity(hasAppeared ? 1 : 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, Theme.sheetRadius + 26)
            .frame(maxWidth: Theme.readableWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .avoidingFold()
        }
        .frame(height: height + topInset)
        .clipped()
    }

    // MARK: Sheet

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            modePicker
            form
            messages
            Button(action: submit) {
                if isWorking {
                    ProgressView().tint(Theme.primaryLabel)
                } else {
                    Text(mode == .signIn ? "Sign in" : "Create account")
                }
            }
            .buttonStyle(PillButtonStyle())
            .disabled(!canSubmit || isWorking)
            .padding(.top, 4)

            Button {} label: {
                Text("Continue with phone · coming soon")
            }
            .buttonStyle(QuietButtonStyle())
            .frame(maxWidth: .infinity)
            .disabled(true)
            .opacity(0.5)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 40)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .avoidingFold()
        .background(
            Theme.background,
            in: UnevenRoundedRectangle(topLeadingRadius: Theme.sheetRadius, topTrailingRadius: Theme.sheetRadius, style: .continuous)
        )
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
                    Text(item.rawValue.uppercased())
                        .font(Typo.font(12, .medium, relativeTo: .caption))
                        .tracking(1.4)
                        .foregroundStyle(mode == item ? Theme.ink : Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background {
                            if mode == item {
                                Capsule()
                                    .fill(Theme.card)
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
        VStack(spacing: 12) {
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
    }

    private func fieldChrome<Content: View>(_ isFocused: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .font(Typo.body)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isFocused ? Theme.ink.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(Theme.ink)
            .animation(.easeOut(duration: 0.2), value: isFocused)
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        field: Field,
        content: UITextContentType,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        fieldChrome(focused == field) {
            TextField("", text: text, prompt: Text(title).foregroundStyle(Theme.secondaryText))
                .textContentType(content)
                .keyboardType(keyboard)
                .textInputAutocapitalization(field == .email ? .never : .words)
                .autocorrectionDisabled()
                .focused($focused, equals: field)
                .submitLabel(.next)
                .onSubmit { advance(from: field) }
                .accessibilityLabel(title)
        }
    }

    private var secureField: some View {
        fieldChrome(focused == .password) {
            SecureField("", text: $password, prompt: Text("Password").foregroundStyle(Theme.secondaryText))
                .textContentType(mode == .signIn ? .password : .newPassword)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .onSubmit(submit)
                .accessibilityLabel("Password")
        }
    }

    @ViewBuilder
    private var messages: some View {
        if let errorText {
            Label(errorText, systemImage: "sparkle")
                .font(Typo.secondary)
                .foregroundStyle(Theme.ink)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.blush, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
        }
        if let infoText {
            Label(infoText, systemImage: "envelope.open")
                .font(Typo.secondary)
                .foregroundStyle(Theme.ink)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
