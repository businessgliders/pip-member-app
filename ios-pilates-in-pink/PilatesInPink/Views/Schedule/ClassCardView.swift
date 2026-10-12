import SwiftUI

struct ClassCardView: View {
    let session: ScheduleSession

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(StudioTime.time(session.startDate))
                .font(.system(size: 19, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 7) {
                Text(session.name)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if session.isCancelled {
                    Text("Cancelled")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                } else {
                    HStack(spacing: 6) {
                        if let level = session.classLevel, !level.isEmpty {
                            Chip(text: level, style: .soft)
                        }
                        if session.isSub {
                            Chip(text: "Sub", style: .outline)
                        }
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            Spacer(minLength: 4)

            if !session.isCancelled {
                availability
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .cardStyle()
        .opacity(session.isCancelled ? 0.5 : (session.hasStarted ? 0.7 : 1))
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let instructor = session.instructorName, !instructor.isEmpty { parts.append("with \(instructor)") }
        parts.append("\(session.durationMinutes) min")
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var availability: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if session.isBooked {
                Chip(text: "Booked", style: .caramel, systemImage: "checkmark")
            } else if session.hasStarted {
                Text("Finished")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
            } else if session.isWaitlisted {
                Chip(text: "On waitlist", style: .blush)
            } else if session.isFull {
                Text("Full")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                Chip(text: "Join waitlist", style: .soft)
            } else {
                HStack(spacing: 4) {
                    Text(session.spotsLeft == 1 ? "1 spot left" : "\(session.spotsLeft) spots left")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(session.spotsLeft <= 2 ? Theme.caramel : Theme.ink)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }
}
