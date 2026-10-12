import SwiftUI

/// Hero card showing the member's own next booked class.
struct NextClassCard: View {
    let booking: Booking?
    let stationNumber: Int?
    let isLoading: Bool
    let onFindClass: () -> Void

    var body: some View {
        Group {
            if isLoading && booking == nil {
                skeleton
            } else if let booking {
                NavigationLink(value: ClassRoute(sessionId: booking.classSessionId, startsAt: booking.startDate)) {
                    bookedContent(booking)
                }
                .buttonStyle(PressableCardStyle())
            } else {
                emptyContent
            }
        }
    }

    private func bookedContent(_ booking: Booking) -> some View {
        ZStack(alignment: .topTrailing) {
            ReformerIcon()
                .stroke(Theme.pink.opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 112, height: 56)
                .padding(.top, 22)
                .padding(.trailing, 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Your next class")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                Text("\(StudioTime.relativeDay(booking.startDate)) · \(StudioTime.time(booking.startDate))")
                    .font(.system(size: 30, weight: .heavy))
                    .tracking(-0.8)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text(booking.className + (booking.level.map { " · \($0)" } ?? ""))
                    .font(.headline.weight(.regular))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    if let stationNumber {
                        Chip(text: "Reformer \(stationNumber)", style: .soft)
                    }
                    Chip(text: "Booked", style: .caramel, systemImage: "checkmark")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your booking")
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your next class")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.secondaryText)
            Text("Nothing booked yet")
                .font(.system(size: 28, weight: .heavy))
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
            Text("Pick a class and choose your reformer — it only takes a tap.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
            Button("Find a class", action: onFindClass)
                .buttonStyle(PillButtonStyle())
                .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonBlock(width: 110, height: 14)
            SkeletonBlock(width: 200, height: 30)
            SkeletonBlock(width: 160, height: 16)
            SkeletonBlock(width: 140, height: 26, radius: 13)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(
                LinearGradient(colors: [Theme.blush, Theme.card], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.softPink.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Theme.pink.opacity(0.14), radius: 22, x: 0, y: 10)
    }
}
