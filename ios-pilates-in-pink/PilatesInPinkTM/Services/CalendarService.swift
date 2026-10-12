import EventKit
import Foundation

/// Adds booked classes to the member's calendar (write-only access).
enum CalendarService {
    enum Outcome { case added, denied }

    static func addClass(title: String, start: Date, end: Date, reformerNumber: Int) async throws -> Outcome {
        let store = EKEventStore()
        let granted = try await store.requestWriteOnlyAccessToEvents()
        guard granted else { return .denied }

        let event = EKEvent(eventStore: store)
        event.title = "\(title) · Reformer \(reformerNumber)"
        event.startDate = start
        event.endDate = end
        event.location = "Pilates in Pink™, Brampton, ON"
        event.timeZone = StudioTime.timeZone
        event.calendar = store.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -60 * 60))
        try store.save(event, span: .thisEvent)
        return .added
    }
}
