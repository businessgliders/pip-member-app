import SwiftUI

/// Full-width schedule row: time + duration | hairline | name, instructor · level, status.
struct ClassRowView: View {
    let session: ScheduleSession
    var isHighlighted: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(StudioTime.time(session.startDate))
                    .font(Typo.font(15, .medium, relativeTo: .subheadline))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("\(session.durationMinutes) min")
                    .font(Typo.font(13, .regular, relativeTo: .footnote))
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(width: 72, alignment: .leading)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
                .frame(minHeight: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name + (session.isSub ? " (Sub)" : ""))
                    .font(Typo.bodyLarge)
                    .foregroundStyle(Theme.ink)
                    .strikethrough(session.isCancelled, color: Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(Typo.secondary)
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            status
                .padding(.top, 1)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(isHighlighted ? Theme.blush.opacity(0.6) : Color.clear)
        .opacity(session.isCancelled || (session.hasStarted && !session.isBooked) ? 0.45 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        [session.instructorName, session.classLevel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var status: some View {
        if session.isCancelled {
            statusText("Cancelled", color: Theme.secondaryText)
        } else if session.isBooked {
            HStack(spacing: 4) {
                Text("Booked")
                Image(systemName: "checkmark").font(.system(size: 11, weight: .medium))
            }
            .font(Typo.font(14, .medium, relativeTo: .subheadline))
            .foregroundStyle(Theme.caramel)
        } else if session.hasStarted {
            statusText("Started", color: Theme.secondaryText)
        } else if session.isWaitlisted {
            Chip(text: "On waitlist", style: .blush)
        } else if session.isFull {
            statusText("Waitlist", color: Theme.ink)
        } else {
            statusText("\(session.spotsLeft) left", color: session.spotsLeft <= 2 ? Theme.ink : Theme.secondaryText)
        }
    }

    private func statusText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(Typo.font(14, .regular, relativeTo: .subheadline))
            .monospacedDigit()
            .foregroundStyle(color)
            .lineLimit(1)
    }
}
