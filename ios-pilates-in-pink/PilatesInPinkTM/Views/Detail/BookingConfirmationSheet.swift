import SwiftUI
import UIKit

/// The one celebration in the app: the two halves of the logo join at the stem over a soft blush
/// glow that fades away, one success haptic, and the details rise in line by line.
struct BookingConfirmationSheet: View {
    private enum CalendarState: Equatable { case idle, adding, added, denied, failed }

    let confirmation: BookingConfirmation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.calmMotion) private var calm
    @State private var calendarState: CalendarState = .idle
    @State private var isJoined = false
    @State private var glow: Double = 1
    @State private var revealStep = 0
    @State private var celebrated = 0

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
        .sensoryFeedback(.success, trigger: celebrated)
        .task { await celebrate() }
    }

    private func celebrate() async {
        guard celebrated == 0 else { return }
        celebrated = 1
        withAnimation(Motion.choose(Motion.bookingJoin, calm: calm)) { isJoined = true }
        withAnimation(Motion.bookingGlowFade.delay(calm ? 0 : 0.3)) { glow = 0 }
        try? await Task.sleep(for: .seconds(calm ? 0.05 : 0.25))
        for step in 1...5 {
            withAnimation(Motion.choose(Motion.ease, calm: calm)) { revealStep = step }
            try? await Task.sleep(for: .seconds(Motion.detailStagger))
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RadialGradient(
                    colors: [Theme.blush, Theme.blush.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 80
                )
                .frame(width: 180, height: 160)
                .opacity(glow)
                LogoMark(size: 76, separation: isJoined || calm ? 0 : Motion.bookingSeparation)
                    .opacity(calm && !isJoined ? 0 : 1)
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .accessibilityHidden(true)

            Text("You're booked")
                .font(Typo.font(34, .light, relativeTo: .largeTitle))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
                .riseIn(revealStep >= 1)

            VStack(spacing: 0) {
                detailRow("Class", confirmation.className)
                    .riseIn(revealStep >= 2)
                Hairline()
                detailRow("Date", StudioTime.format(confirmation.start, "EEEE, MMM d"))
                    .riseIn(revealStep >= 3)
                Hairline()
                detailRow("Time", StudioTime.timeRange(confirmation.start, confirmation.end))
                    .riseIn(revealStep >= 4)
                Hairline()
                detailRow("Reformer", "\(confirmation.reformerNumber)")
                    .riseIn(revealStep >= 5)
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
                withAnimation(Motion.fade) { calendarState = outcome == .added ? .added : .denied }
            } catch {
                withAnimation(Motion.fade) { calendarState = .failed }
            }
        }
    }
}
