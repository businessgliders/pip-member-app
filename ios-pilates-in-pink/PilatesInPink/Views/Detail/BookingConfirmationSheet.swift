import SwiftUI
import UIKit

struct BookingConfirmationSheet: View {
    private enum CalendarState: Equatable { case idle, adding, added, denied, failed }

    let confirmation: BookingConfirmation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var calendarState: CalendarState = .idle
    @State private var hasAppeared: Bool = false
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34

    private let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat, delay: Double)] = [
        (-110, -30, 18, 0.05), (-80, 34, 12, 0.15), (-130, 18, 10, 0.25),
        (110, -26, 16, 0.1), (84, 38, 12, 0.2), (132, 10, 9, 0.3)
    ]

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(Array(sparkles.enumerated()), id: \.offset) { _, sparkle in
                    Image(systemName: "sparkle")
                        .font(.system(size: sparkle.size, weight: .bold))
                        .foregroundStyle(Theme.pink.opacity(0.7))
                        .offset(x: sparkle.x, y: sparkle.y)
                        .scaleEffect(hasAppeared ? 1 : 0.1)
                        .opacity(hasAppeared ? 1 : 0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(sparkle.delay), value: hasAppeared)
                }
                Circle()
                    .fill(Theme.softPink.opacity(0.55))
                    .frame(width: 112, height: 112)
                    .scaleEffect(hasAppeared ? 1 : 0.6)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .symbolEffect(.bounce, value: hasAppeared)
            }
            .frame(height: 130)
            .padding(.top, 8)
            .accessibilityHidden(true)

            Text("You're booked ✨")
                .font(.system(size: titleSize, weight: .heavy))
                .tracking(-1)
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)

            Text(confirmation.summary)
                .font(.body.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            if calendarState == .denied {
                Text("Calendar access is off. You can turn it on in Settings.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            } else if calendarState == .failed {
                Text("We couldn't add it just now — give it another try.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Spacer(minLength: 8)

            calendarButton

            Button("Done") { dismiss() }
                .buttonStyle(PillButtonStyle(kind: .secondary))
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .presentationDetents([.height(500), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        .presentationBackground {
            LinearGradient(colors: [Theme.blush, Theme.background], startPoint: .top, endPoint: .bottom)
        }
        .sensoryFeedback(.success, trigger: calendarState == .added)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { hasAppeared = true }
        }
    }

    @ViewBuilder
    private var calendarButton: some View {
        switch calendarState {
        case .added:
            Button {} label: {
                Label("Added to your calendar", systemImage: "checkmark")
            }
            .buttonStyle(PillButtonStyle())
            .disabled(true)
        case .denied:
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(PillButtonStyle())
        default:
            Button(action: addToCalendar) {
                if calendarState == .adding {
                    ProgressView().tint(Theme.onPink)
                } else {
                    Text("Add to Calendar")
                }
            }
            .buttonStyle(PillButtonStyle())
            .disabled(calendarState == .adding)
        }
    }

    private func addToCalendar() {
        calendarState = .adding
        Task {
            do {
                let outcome = try await CalendarService.addClass(
                    title: confirmation.className,
                    start: confirmation.start,
                    end: confirmation.end,
                    reformerNumber: confirmation.reformerNumber
                )
                withAnimation(Theme.spring) { calendarState = outcome == .added ? .added : .denied }
            } catch {
                withAnimation(Theme.spring) { calendarState = .failed }
            }
        }
    }
}
