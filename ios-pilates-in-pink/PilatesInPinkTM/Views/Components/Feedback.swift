import SwiftUI

/// Loading placeholder: a blush block with a slow, soft highlight sweeping across (1.6s).
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var radius: CGFloat = 8
    @Environment(\.calmMotion) private var calm
    @State private var sweep: CGFloat = -1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(Theme.blush.opacity(0.7))
            .overlay {
                if !calm {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, Theme.card.opacity(0.75), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: max(60, proxy.size.width * 0.6))
                        .offset(x: sweep * proxy.size.width * 1.3)
                    }
                }
            }
            .clipShape(shape)
            .frame(width: width, height: height)
            .onAppear {
                guard !calm else { return }
                withAnimation(.easeInOut(duration: Motion.shimmerSweep).repeatForever(autoreverses: false)) {
                    sweep = 1
                }
            }
            .accessibilityHidden(true)
    }
}

/// Skeleton matching a class/reservation row.
struct RowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 56, height: 14)
                SkeletonBlock(width: 40, height: 11)
            }
            .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 170, height: 15)
                SkeletonBlock(width: 120, height: 12)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
    }
}

/// Inline card for errors, always with a next step.
struct ErrorCard: View {
    let error: FriendlyError
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(Typo.font(16, .medium, relativeTo: .headline))
                        .foregroundStyle(Theme.ink)
                    Text(error.message)
                        .font(Typo.secondary)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Dismiss")
                }
            }
            if error.kind == .outOfCredits {
                Button {} label: { Text("Buy credits — coming soon") }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .disabled(true)
            } else if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PillButtonStyle(kind: .secondary))
            }
        }
        .cardStyle(padding: 18)
    }

    private var icon: String {
        switch error.kind {
        case .offline: "wifi.slash"
        case .outOfCredits: "creditcard"
        case .stationTaken: "arrow.triangle.2.circlepath"
        default: "sparkle"
        }
    }
}

/// Calm empty state with a line icon, or the logo mark (40pt, blush, 60%).
struct EmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    var showsLogo: Bool = false
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            if showsLogo {
                LogoMark(size: 40, style: .quiet)
                    .opacity(0.6)
                    .frame(height: 44)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .ultraLight))
                    .foregroundStyle(Theme.ink)
                    .frame(height: 44)
            }
            Text(title)
                .font(Typo.font(20, .light, relativeTo: .title3))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(Typo.secondary)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PillButtonStyle())
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .cardStyle(padding: 24)
    }
}

/// Small top toast for positive confirmations.
struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.onPink)
                .frame(width: 22, height: 22)
                .background(Theme.pink, in: Circle())
            Text(text)
                .font(Typo.font(15, .regular, relativeTo: .subheadline))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .glass(Capsule())
        .padding(.horizontal, 20)
    }
}
