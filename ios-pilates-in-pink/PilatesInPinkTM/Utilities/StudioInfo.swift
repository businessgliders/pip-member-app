import Foundation

/// Bundled studio details (from the studio's public listing). Edit here to update.
enum StudioInfo {
    static let name = "Pilates in Pink™"
    static let city = "Brampton"
    static let addressLines = ["6161 Mayfield Road, Unit 105", "Brampton, ON L6P 2W8"]
    static let phoneDisplay = "(866) 757-7465"
    static let phoneURL = URL(string: "tel://18667577465")
    static let website = URL(string: "https://www.pilatesinpinkstudio.com")
    static let contactPage = URL(string: "https://www.pilatesinpinkstudio.com/contact")
    /// Help & Support opens a message to this inbox.
    static let supportEmail: String? = "support@pilatesinpinkstudio.com"
    static let mapsURL = URL(string: "http://maps.apple.com/?q=Pilates%20in%20Pink&address=6161%20Mayfield%20Rd%20Unit%20105,%20Brampton,%20ON%20L6P%202W8")

    static var helpURL: URL? {
        if let supportEmail { return URL(string: "mailto:\(supportEmail)?subject=Pilates%20in%20Pink%20app") }
        return contactPage
    }

    /// Opening hours in minutes from midnight, keyed by weekday (1 = Sunday … 7 = Saturday).
    static let hours: [Int: [ClosedRange<Int>]] = {
        let weekday = [390...750, 990...1230]   // 6:30 AM–12:30 PM, 4:30–8:30 PM
        let weekend = [510...1170]              // 8:30 AM–7:30 PM
        return [1: weekend, 2: weekday, 3: weekday, 4: weekday, 5: weekday, 6: weekday, 7: weekend]
    }()

    static func clock(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        let hour12 = h % 12 == 0 ? 12 : h % 12
        let suffix = h < 12 ? "AM" : "PM"
        return m == 0 ? "\(hour12) \(suffix)" : String(format: "%d:%02d %@", hour12, m, suffix)
    }

    static func hoursText(weekday: Int) -> String {
        guard let ranges = hours[weekday], !ranges.isEmpty else { return "Closed" }
        return ranges.map { "\(clock($0.lowerBound)) – \(clock($0.upperBound))" }.joined(separator: ", ")
    }

    /// "Open now · until 12:30 PM", "Opens today at 4:30 PM", "Closed now · opens Fri 6:30 AM"
    static func statusLine(now: Date = Date()) -> String {
        let cal = StudioTime.calendar
        let weekday = cal.component(.weekday, from: now)
        let minutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let today = hours[weekday] ?? []
        if let open = today.first(where: { $0.contains(minutes) }) {
            return "Open now · until \(clock(open.upperBound))"
        }
        if let next = today.first(where: { $0.lowerBound > minutes }) {
            return "Opens today at \(clock(next.lowerBound))"
        }
        for offset in 1...7 {
            let day = (weekday - 1 + offset) % 7 + 1
            if let first = hours[day]?.first {
                let date = StudioTime.addDays(offset, to: now)
                return "Closed now · opens \(StudioTime.format(date, "EEE")) \(clock(first.lowerBound))"
            }
        }
        return "Hours coming soon"
    }
}
