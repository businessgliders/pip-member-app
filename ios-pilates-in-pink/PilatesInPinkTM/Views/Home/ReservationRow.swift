import SwiftUI

/// Upcoming booking: SUN / 8 / NOV date block, class name, time · duration · reformer, instructor.
struct ReservationRow: View {
    let booking: Booking
    let session: ScheduleSession?
    let reformerNumber: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 2) {
                Text(StudioTime.format(booking.startDate, "EEE").uppercased())
                    .font(Typo.font(11, .medium, relativeTo: .caption2))
                    .tracking(1.2)
                    .foregroundStyle(Theme.secondaryText)
                Text(StudioTime.format(booking.startDate, "d"))
                    .font(Typo.font(26, .light, relativeTo: .title2))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text(StudioTime.format(booking.startDate, "MMM").uppercased())
                    .font(Typo.font(11, .medium, relativeTo: .caption2))
                    .tracking(1.2)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(width: 58, height: 72)
            .background(Theme.blush, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(booking.className + ((session?.isSub ?? false) ? " (Sub)" : ""))
                    .font(Typo.bodyLarge)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(detailLine)
                    .font(Typo.secondary)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let instructor = session?.instructorName, !instructor.isEmpty {
                    Text(instructor)
                        .font(Typo.secondary)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Theme.secondaryText)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var detailLine: String {
        let minutes = max(0, Int(booking.endDate.timeIntervalSince(booking.startDate) / 60))
        var parts = [StudioTime.time(booking.startDate)]
        if minutes > 0 { parts.append("\(minutes) min") }
        if let reformerNumber { parts.append("Reformer \(reformerNumber)") }
        return parts.joined(separator: " · ")
    }
}

/// Card skeleton for a reservation row.
struct ReservationSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            SkeletonBlock(width: 58, height: 72, radius: 14)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 160, height: 16)
                SkeletonBlock(width: 190, height: 12)
                SkeletonBlock(width: 90, height: 12)
            }
            Spacer()
        }
    }
}
