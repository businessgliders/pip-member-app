import Foundation
import Observation
import SwiftUI

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
    /// Only written through `select(_:source:)`, so every change is logged with who made it.
    private(set) var selectedTab: AppTab = .home
    /// When the member last switched tabs from the tab bar / sidebar. Programmatic switches
    /// that arrive while that transition is still running are ignored, so nothing can bounce
    /// the selection back mid-animation.
    @ObservationIgnored private var lastTabBarSwitch = Date.distantPast
    @ObservationIgnored private let transitionGuard: TimeInterval = 0.6
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

    enum TabSource: String {
        case tabBar, openClasses, openMe
    }

    /// The single place `selectedTab` changes.
    @discardableResult
    func select(_ tab: AppTab, source: TabSource) -> Bool {
        let old = selectedTab
        if source == .tabBar {
            lastTabBarSwitch = Date()
        } else if Date().timeIntervalSince(lastTabBarSwitch) < transitionGuard {
            print("[Tab] ignored \(old) -> \(tab) from \(source.rawValue): tab-bar switch in flight")
            return false
        }
        print("[Tab] \(old) -> \(tab) from \(source.rawValue)")
        guard tab != old else { return true }
        selectedTab = tab
        return true
    }

    /// Binding for the TabView: the tab bar's own selection, logged as `.tabBar`.
    var tabBarSelection: Binding<AppTab> {
        Binding(
            get: { self.selectedTab },
            set: { self.select($0, source: .tabBar) }
        )
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
        guard select(.classes, source: .openClasses) else { return }
        if let family {
            pendingClassFilter = family
            pendingFilterToken += 1
        }
        classesPath = []
        classesSelection = nil
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
        guard select(.me, source: .openMe) else { return }
        if let route { mePath = [route] }
    }
}
