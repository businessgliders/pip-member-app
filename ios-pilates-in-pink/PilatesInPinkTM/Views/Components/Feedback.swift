import SwiftUI

/// Pulsing placeholder block used for loading skeletons.
struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var radius: CGFloat = 8
    @State private var isPulsing = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Theme.taken)
            .frame(width: width, height: height)
            .opacity(isPulsing ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
            .accessibilityHidden(true)
    }
}

struct ClassCardSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            SkeletonBlock(width: 78, height: 22)
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(width: 150, height: 18)
                SkeletonBlock(width: 70, height: 22, radius: 11)
                SkeletonBlock(width: 120, height: 14)
            }
            Spacer()
        }
        .cardStyle()
    }
}

/// Inline card for errors, always with a next step.
struct ErrorCard: View {
    let error: FriendlyError
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.caramel)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.title)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(error.message)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Theme.secondaryText)
                            .frame(width: 32, height: 32)
                    }
                    .accessibilityLabel("Dismiss")
                }
            }
            if error.kind == .outOfCredits {
                Button {} label: {
                    Label("Buy credits — coming soon", systemImage: "sparkles")
                }
                .buttonStyle(PillButtonStyle(kind: .secondary))
                .disabled(true)
            } else if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PillButtonStyle(kind: .secondary))
            }
        }
        .cardStyle(padding: 16)
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

/// Friendly empty state.
struct EmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.blush).frame(width: 72, height: 72)
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle(padding: 24)
    }
}

/// Small top toast for positive confirmations.
struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.success)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Theme.card, in: Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 20)
    }
}
