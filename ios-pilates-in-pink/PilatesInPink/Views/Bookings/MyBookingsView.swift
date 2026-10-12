import SwiftUI

struct MyBookingsView: View {
    @Environment(StudioStore.self) private var store
    @Environment(Router.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ScreenTitle(text: "My Bookings")
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                content
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.bottom, Theme.tabBarClearance, for: .scrollContent)
        .background(ScreenBackground())
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.refreshAll() }
        .task {
            await store.loadStationsIfNeeded()
            if !store.hasLoadedBookings { await store.refreshBookings() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.hasLoadedBookings {
            ForEach(0..<3, id: \.self) { _ in ClassCardSkeleton() }
        } else if let error = store.bookingsError, store.bookings.isEmpty {
            ErrorCard(error: error, actionTitle: "Try again") {
                Task { await store.refreshBookings() }
            }
        } else if store.upcomingBookings.isEmpty {
            EmptyStateCard(
                systemImage: "ticket",
                title: "No upcoming classes yet",
                message: "Your booked classes will live here. Find one you love on the schedule.",
                actionTitle: "Browse classes"
            ) {
                router.selectedTab = .schedule
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(store.upcomingBookings) { booking in
                    NavigationLink(value: ClassRoute(sessionId: booking.classSessionId, startsAt: booking.startDate)) {
                        BookingCardView(booking: booking, stationNumber: store.stationNumber(for: booking.stationId))
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .animation(Theme.spring, value: store.upcomingBookings.map(\.id))
        }
    }
}

struct BookingCardView: View {
    let booking: Booking
    let stationNumber: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(StudioTime.relativeDay(booking.startDate))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondaryText)
                Text(StudioTime.format(booking.startDate, "MMM d"))
                    .font(.system(size: 24, weight: .heavy))
                    .tracking(-0.6)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 88, alignment: .leading)

            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 6) {
                Text(StudioTime.time(booking.startDate))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                Text(booking.className)
                    .font(.body)
                    .foregroundStyle(Theme.ink)
                if let stationNumber {
                    Chip(text: "Reformer \(stationNumber)", style: .soft)
                }
            }

            Spacer(minLength: 4)

            Chip(text: "Booked", style: .caramel, systemImage: "checkmark")
        }
        .fixedSize(horizontal: false, vertical: true)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens booking to change reformer or cancel")
    }
}
