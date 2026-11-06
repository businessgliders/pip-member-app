import Foundation
import Observation

enum AppTab: Int, CaseIterable, Hashable {
    case home, classes, card, me

    var title: String {
        switch self {
        case .home: "Home"
        case .classes: "Classes"
        case .card: "Card"
        case .me: "Me"
        }
    }

    var icon: String {
        switch self {
        case .home: "house"
        case .classes: "calendar"
        case .card: "qrcode"
        case .me: "person"
        }
    }
}

enum AppRoute: Hashable {
    case classDetail(ClassRoute)
    case reservations
    case credits
    case notifications
    case account
}

@Observable
final class Router {
    var selectedTab: AppTab = .home
    var homePath: [AppRoute] = []
    var classesPath: [AppRoute] = []
    var cardPath: [AppRoute] = []
    var mePath: [AppRoute] = []

    /// A class family the Classes tab should filter by next time it appears.
    private(set) var pendingClassFilter: ClassFamily?
    private(set) var pendingFilterToken = 0

    /// The class open in the Classes tab. Shared by the pushed (compact) and
    /// split (regular) layouts so it survives folds and rotations.
    var classesSelection: ClassRoute?

    func select(_ tab: AppTab) {
        if tab == selectedTab {
            popToRoot(tab)
        } else {
            selectedTab = tab
        }
    }

    func popToRoot(_ tab: AppTab) {
        switch tab {
        case .home: homePath = []
        case .classes:
            classesPath = []
            classesSelection = nil
        case .card: cardPath = []
        case .me: mePath = []
        }
    }

    /// Opens the Classes tab, optionally filtered to one class family (nil clears nothing).
    func openClasses(family: ClassFamily? = nil) {
        if let family {
            pendingClassFilter = family
            pendingFilterToken += 1
        }
        classesPath = []
        classesSelection = nil
        selectedTab = .classes
    }

    func consumePendingFilter() -> ClassFamily? {
        defer { pendingClassFilter = nil }
        return pendingClassFilter
    }

    func push(_ route: AppRoute) {
        switch selectedTab {
        case .home: homePath.append(route)
        case .classes: classesPath.append(route)
        case .card: cardPath.append(route)
        case .me: mePath.append(route)
        }
    }

    func openMe(_ route: AppRoute? = nil) {
        selectedTab = .me
        if let route { mePath = [route] }
    }
}
