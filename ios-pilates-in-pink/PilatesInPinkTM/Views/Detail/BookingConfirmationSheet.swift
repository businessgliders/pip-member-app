import SwiftUI
import UIKit

struct BookingConfirmationSheet: View {
    private enum CalendarState: Equatable { case idle, adding, added, denied, failed }

    let confirmation: BookingConfirmation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var calendarState: CalendarState = .idle
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            summary
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                calendarButton
                Button("Done") { dismiss() }
                    .buttonStyle(PillButtonStyle(kind: .secondary))
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Theme.background)
        }
        .avoidingFold()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Theme.sheetRadius)
        .presentationBackground(Theme.background)
        .sensoryFeedback(.success, trigger: calendarState == .added)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.1)) { hasAppeared = true }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                Circle()
                    .fill(Theme.blush)
                    .frame(width: 84, height: 84)
                    .scaleEffect(hasAppeared ? 1 : 0.6)
                Circle()
                    .fill(Theme.pink)
                    .frame(width: 52, height: 52)
                    .scaleEffect(hasAppeared ? 1 : 0.3)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.onPink)
                    .opacity(hasAppeared ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 22)
            .accessibilityHidden(true)

            Text("You're booked")
                .font(Typo.font(34, .light, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                detailRow("Class", confirmation.className)
                Hairline()
                detailRow("Date", StudioTime.format(confirmation.start, "EEEE, MMM d"))
                Hairline()
                detailRow("Time", StudioTime.timeRange(confirmation.start, confirmation.end))
                Hairline()
                detailRow("Reformer", "\(confirmation.reformerNumber)")
            }
            .padding(.horizontal, 18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

            if calendarState == .denied {
                note("Calendar access is off. You can turn it on in Settings.")
            } else if calendarState == .failed {
                note("We couldn't add it just now — give it another try.")
            }

        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            EyebrowText(label)
            Spacer()
            Text(value)
                .font(Typo.body)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 50)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typo.secondary)
            .foregroundStyle(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 14)
    }

    @ViewBuilder
    private var calendarButton: some View {
        switch calendarState {
        case .added:
            Button {} label: { Label("Added to Calendar", systemImage: "checkmark") }
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
                    ProgressView().tint(Theme.primaryLabel)
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
