import Foundation
import Observation

enum AppTab: Int, CaseIterable, Hashable {
    case schedule, bookings, account

    var title: String {
        switch self {
        case .schedule: "Schedule"
        case .bookings: "My Bookings"
        case .account: "Account"
        }
    }

    var icon: String {
        switch self {
        case .schedule: "calendar"
        case .bookings: "ticket"
        case .account: "person"
        }
    }
}

@Observable
final class Router {
    var selectedTab: AppTab = .schedule
    var schedulePath: [ClassRoute] = []
    var bookingsPath: [ClassRoute] = []

    /// The floating tab bar only shows on top-level screens.
    var isTabBarVisible: Bool {
        switch selectedTab {
        case .schedule: schedulePath.isEmpty
        case .bookings: bookingsPath.isEmpty
        case .account: true
        }
    }
}
