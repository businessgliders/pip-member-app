import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var router = Router()
    @State private var store = StudioStore()
    @State private var bannerStore = BannerStore()
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var wasInBackground = false

    var body: some View {
        // The tab bar writes the selection only through the router, which logs every change.
        TabView(selection: router.tabBarSelection) {
            Tab(value: AppTab.home) {
                NavigationStack(path: $router.homePath) {
                    HomeView().appDestinations()
                }
                .tint(Theme.ink)
            } label: { tabLabel(.home) }

            Tab(value: AppTab.classes) {
                ClassesView()
                    .tint(Theme.ink)
            } label: { tabLabel(.classes) }

            Tab(value: AppTab.card) {
                NavigationStack(path: $router.cardPath) {
                    MemberCardView().appDestinations()
                }
                .tint(Theme.ink)
            } label: { tabLabel(.card) }

            Tab(value: AppTab.me) {
                NavigationStack(path: $router.mePath) {
                    MeView().appDestinations()
                }
                .tint(Theme.ink)
            } label: { tabLabel(.me) }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Pink marks the selected tab; screen content and toolbars stay ink.
        .tint(Theme.pink)
        .background(Theme.background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: router.selectedTab)
        .environment(router)
        .environment(store)
        .environment(bannerStore)
        .task { await bannerStore.refresh() }
        .task {
            await store.refreshAll()
            await store.loadClassTypesIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: wasInBackground = true
            case .active:
                // Back in the foreground: pick up any new banners.
                guard wasInBackground else { return }
                wasInBackground = false
                Task { await bannerStore.refresh() }
            default: break
            }
        }
    }

    /// Icon-only in the tab bar (title kept for VoiceOver); titled in the iPad / inner-display sidebar.
    @ViewBuilder
    private func tabLabel(_ tab: AppTab) -> some View {
        if hSize == .regular {
            Label(tab.title, systemImage: tab.icon)
        } else {
            Label(tab.title, systemImage: tab.icon)
                .labelStyle(.iconOnly)
        }
    }
}

// MARK: - Destinations

extension View {
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            AppDestination(route: route)
        }
    }
}

struct AppDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .classDetail(let classRoute): ClassDetailView(route: classRoute)
        case .reservations: ReservationsView()
        case .credits: CreditsView()
        case .notifications: NotificationsView()
        case .account: AccountDetailsView()
        }
    }
}

// MARK: - Keep swipe-back on screens with a hidden navigation bar

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

// MARK: - Shared chrome for pushed screens

extension View {
    /// System navigation bar (back button placed by the system), transparent over the cream canvas.
    func pushedScreenChrome() -> some View {
        self
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

/// Light title for pushed text screens; the system bar above it holds Back.
struct PushedHeader: View {
    let title: String

    var body: some View {
        ScreenTitle(text: title)
            .padding(.top, 4)
    }
}
