import SwiftUI
import UserNotifications

/// First-time setup after sign-in, on the same blurred poster as sign-in, with a 4-part
/// progress bar: C. name + terms, D. photo, E. birthday, F. notifications.
struct OnboardingView: View {
    enum Step: Int, CaseIterable { case name = 1, photo, birthday, notifications }

    let profile: MemberProfile?
    let userId: UUID
    /// Accepted on create-account already: the name step hides the Terms checkbox.
    let termsAccepted: Bool
    let onFinish: () -> Void

    @Environment(AuthStore.self) private var auth
    @Environment(\.calmMotion) private var calm
    @State private var step: Step
    @State private var firstName: String
    @State private var lastName: String
    @State private var agreesToTerms = false
    @State private var wantsMarketing = false
    @State private var photo: UIImage?
    @State private var choosesPhoto = false
    @State private var birthday: Date
    @State private var hasChosenBirthday = false
    @State private var isWorking = false
    @State private var notice: String?
    @State private var safariLink: SafariLink?
    @State private var confirmsLeave = false
    @FocusState private var focus: Field?

    private enum Field: Hashable { case first, last }
    private let service = StudioService()

    init(profile: MemberProfile?, userId: UUID, start: Step, termsAccepted: Bool = false, onFinish: @escaping () -> Void) {
        self.profile = profile
        self.userId = userId
        self.termsAccepted = termsAccepted
        self.onFinish = onFinish
        _step = State(initialValue: start)
        _firstName = State(initialValue: profile?.firstName ?? "")
        _lastName = State(initialValue: profile?.lastName ?? "")
        let fallback = Calendar(identifier: .gregorian).date(from: DateComponents(year: 1995, month: 1, day: 1)) ?? Date()
        _birthday = State(initialValue: profile?.birthdayDate ?? fallback)
        _hasChosenBirthday = State(initialValue: profile?.birthdayDate != nil)
    }

    var body: some View {
        ZStack {
            AuthBackdrop()
            VStack(spacing: 0) {
                AuthHeader(progress: step.rawValue, onClose: close)
                ZStack {
                    switch step {
                    case .name: nameStep.transition(.authStep(calm: calm))
                    case .photo: photoStep.transition(.authStep(calm: calm))
                    case .birthday: birthdayStep.transition(.authStep(calm: calm))
                    case .notifications: notificationsStep.transition(.authStep(calm: calm))
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
        .confirmationDialog("Finish setting up later?", isPresented: $confirmsLeave, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { Task { await auth.signOut() } }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("You'll be signed out and can pick up here next time.")
        }
        .photoChooser(isPresented: $choosesPhoto) { image in
            withAnimation(Motion.choose(Motion.ease, calm: calm)) { photo = image }
        }
        .task(id: step) {
            guard step == .name, firstName.isEmpty else { return }
            try? await Task.sleep(for: .seconds(Motion.short))
            focus = .first
        }
    }

    // MARK: Flow

    private func go(_ next: Step) {
        focus = nil
        withAnimation(Motion.choose(Motion.authStep, calm: calm)) {
            notice = nil
            step = next
        }
    }

    private func advance() {
        if let next = Step(rawValue: step.rawValue + 1) {
            go(next)
        } else {
            onFinish()
        }
    }

    /// Name and terms are required; the optional steps can be skipped with the X.
    private func close() {
        if step == .name {
            confirmsLeave = true
        } else {
            onFinish()
        }
    }

    private func showNotice(_ text: String?) {
        withAnimation(Motion.choose(Motion.fade, calm: calm)) { notice = text }
    }

    @ViewBuilder
    private var noticeView: some View {
        if let notice {
            AuthNotice(kind: .error, text: notice)
                .padding(.top, 16)
                .transition(Motion.rise(calm: calm))
        }
    }

    private func primaryLabel(_ text: String) -> some View {
        ZStack {
            Text(text).opacity(isWorking ? 0 : 1)
            if isWorking { ProgressView().tint(Theme.fixedInk) }
        }
    }

    // MARK: C. Name + terms

    private var canSaveName: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && (agreesToTerms || termsAccepted)
    }

    private var focusKey: String? {
        focus.map { "\($0)" }
    }

    private var nameStep: some View {
        AuthFormStep(focusKey: focusKey) {
            AuthTitle(text: "looks like you're new here")
            HStack(spacing: 12) {
                AuthFieldBox(isFocused: focus == .first) {
                    TextField("", text: $firstName, prompt: authPrompt("First name"))
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focus, equals: .first)
                        .onSubmit { focus = .last }
                }
                AuthFieldBox(isFocused: focus == .last) {
                    TextField("", text: $lastName, prompt: authPrompt("Last name"))
                        .textContentType(.familyName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.continue)
                        .focused($focus, equals: .last)
                        .onSubmit {
                            focus = nil
                            saveName()
                        }
                }
            }
            .padding(.top, 28)
            VStack(alignment: .leading, spacing: 16) {
                if !termsAccepted {
                    AuthCheckRow(isOn: $agreesToTerms, label: termsAgreementText,
                                 accessibilityText: "I agree to the Terms and Privacy Policy")
                }
                AuthCheckRow(
                    isOn: $wantsMarketing,
                    label: Text("Send me class openings, offers and studio news by email and text. Unsubscribe anytime."),
                    accessibilityText: "Send me class openings, offers and studio news"
                )
            }
            .padding(.top, 16)
            noticeView
            Button(action: saveName) { primaryLabel("CONTINUE") }
                .buttonStyle(CreamPillButtonStyle())
                .disabled(!canSaveName || isWorking)
                .authPrimaryAnchor()
                .padding(.top, 20)
        }
    }

    private func saveName() {
        guard canSaveName, !isWorking else { return }
        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last = lastName.trimmingCharacters(in: .whitespaces)
        let marketing = wantsMarketing
        isWorking = true
        showNotice(nil)
        Task {
            defer { isWorking = false }
            do {
                try await service.updateProfile(firstName: first, lastName: last, marketing: marketing)
                advance()
            } catch {
                showNotice(FriendlyError.isCancellation(error) ? nil : "We couldn't save that just now — please try again.")
            }
        }
    }

    // MARK: D. Photo

    private var photoStep: some View {
        AuthStep {
            AuthTitle(text: "make it yours")
            AuthCaption(text: "Add a photo so the studio team can greet you by name.")
                .padding(.top, 8)
            GeometryReader { proxy in
                let side = proxy.size.width * 0.6
                Button { choosesPhoto = true } label: {
                    ZStack {
                        Circle().fill(Theme.cream.opacity(0.08))
                        if let photo {
                            Image(uiImage: photo)
                                .resizable()
                                .scaledToFill()
                                .frame(width: side, height: side)
                                .clipShape(Circle())
                                .transition(.opacity)
                        } else {
                            Image(systemName: "person")
                                .font(.system(size: side * 0.36, weight: .ultraLight))
                                .foregroundStyle(Theme.cream.opacity(0.55))
                        }
                        Circle().strokeBorder(Theme.cream.opacity(photo == nil ? 0.3 : 0.5), lineWidth: 1)
                    }
                    .frame(width: side, height: side)
                    .contentShape(Circle())
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel(photo == nil ? "Add a photo" : "Change photo")
                .frame(maxWidth: .infinity)
            }
            .aspectRatio(1 / 0.6, contentMode: .fit)
            .padding(.top, 32)
            Button(photo == nil ? "Add a photo" : "Choose a different photo") { choosesPhoto = true }
                .buttonStyle(CreamLinkButtonStyle())
                .padding(.top, 12)
            noticeView
        } actions: {
            Button(action: savePhoto) { primaryLabel("CONTINUE") }
                .buttonStyle(CreamPillButtonStyle())
                .disabled(photo == nil || isWorking)
            Button("Not now") { advance() }
                .buttonStyle(CreamLinkButtonStyle())
                .disabled(isWorking)
        }
    }

    private func savePhoto() {
        guard let photo, !isWorking else { return }
        guard let jpeg = MemberPhoto.jpeg(from: photo) else {
            showNotice("That photo didn't work — try another one.")
            return
        }
        let userId = self.userId
        isWorking = true
        showNotice(nil)
        Task {
            defer { isWorking = false }
            do {
                try await MemberPhoto.upload(jpeg, userId: userId)
                advance()
            } catch {
                print("Photo upload failed: \(error.localizedDescription)")
                showNotice("We couldn't upload your photo just now — try again, or tap Not now.")
            }
        }
    }

    // MARK: E. Birthday

    private var birthdayText: String {
        hasChosenBirthday ? birthday.formatted(.dateTime.month(.wide).day().year()) : "Your birthday"
    }

    private var birthdayStep: some View {
        AuthStep {
            AuthTitle(text: "let's celebrate you")
            AuthFieldBox(isFocused: true) {
                HStack {
                    Image(systemName: "gift")
                        .font(.system(size: 16, weight: .light))
                    Text(birthdayText)
                        .foregroundStyle(Theme.cream.opacity(hasChosenBirthday ? 1 : 0.45))
                        .contentTransition(.numericText())
                    Spacer()
                }
            }
            .padding(.top, 28)
            .accessibilityElement(children: .combine)
            DatePicker("Birthday", selection: $birthday, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_US"))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .onChange(of: birthday) { _, _ in
                    withAnimation(Motion.fade) { hasChosenBirthday = true }
                }
            AuthCaption(text: "Add your birthday for a little something from us.")
                .padding(.top, 4)
            noticeView
        } actions: {
            Button(action: saveBirthday) { primaryLabel("CONTINUE") }
                .buttonStyle(CreamPillButtonStyle())
                .disabled(!hasChosenBirthday || isWorking)
            Button("Not now") { advance() }
                .buttonStyle(CreamLinkButtonStyle())
                .disabled(isWorking)
        }
    }

    private func saveBirthday() {
        guard hasChosenBirthday, !isWorking else { return }
        let value = Self.isoDay(birthday)
        isWorking = true
        showNotice(nil)
        Task {
            defer { isWorking = false }
            do {
                try await service.updateBirthday(value)
                advance()
            } catch {
                showNotice("We couldn't save your birthday just now — try again, or tap Not now.")
            }
        }
    }

    static func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: F. Notifications

    private var notificationsStep: some View {
        AuthStep {
            NotificationSample()
                .padding(.bottom, 32)
            AuthTitle(text: "be the first to know")
            AuthCaption(text: "Waitlist openings, class reminders and studio news.")
                .padding(.top, 8)
        } actions: {
            Button(action: allowNotifications) { primaryLabel("ALLOW NOTIFICATIONS") }
                .buttonStyle(CreamPillButtonStyle())
                .disabled(isWorking)
            Button("Not now") { onFinish() }
                .buttonStyle(CreamLinkButtonStyle())
                .disabled(isWorking)
        }
    }

    private func allowNotifications() {
        isWorking = true
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            isWorking = false
            onFinish()
        }
    }
}

/// A sample lock-screen notification.
private struct NotificationSample: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BrandMark(size: 38)
                .padding(4)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text("Pilates in Pink™")
                        .font(Typo.font(15, .medium, relativeTo: .subheadline))
                    Spacer()
                    Text("now")
                        .font(Typo.font(13, .regular, relativeTo: .caption))
                        .foregroundStyle(Theme.cream.opacity(0.6))
                }
                Text("A spot just opened in Core in Blush at 6:30 PM")
                    .font(Typo.font(15, .regular, relativeTo: .subheadline))
                    .foregroundStyle(Theme.cream.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.cream)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.cream.opacity(0.15), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example notification: Pilates in Pink™. A spot just opened in Core in Blush at 6:30 PM")
    }
}
