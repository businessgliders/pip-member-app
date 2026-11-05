import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var router = Router()
    @State private var store = StudioStore()
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    private var isVerticalNav: Bool { hSize == .regular || vSize == .compact }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            tabStack(.home, path: $router.homePath) { HomeView() }
            tabStack(.classes, path: $router.classesPath) { ClassesView() }
            tabStack(.card, path: $router.cardPath) { MemberCardView() }
            tabStack(.me, path: $router.mePath) { MeView() }
        }
        .overlay(alignment: isVerticalNav ? .trailing : .bottom) {
            if router.isNavVisible {
                FloatingNav(selection: router.selectedTab, vertical: isVerticalNav) { router.select($0) }
                    .padding(isVerticalNav ? .trailing : .bottom, isVerticalNav ? 14 : 4)
                    .transition(.move(edge: isVerticalNav ? .trailing : .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: router.isNavVisible)
        .ignoresSafeArea(.keyboard)
        .environment(router)
        .environment(store)
        .environment(\.navInset, isVerticalNav ? .vertical : .horizontal)
        .task {
            await store.refreshAll()
            await store.loadClassTypesIfNeeded()
        }
    }

    private func tabStack<Root: View>(_ tab: AppTab, path: Binding<[AppRoute]>, @ViewBuilder root: () -> Root) -> some View {
        let isActive = router.selectedTab == tab
        return NavigationStack(path: path) {
            root()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(route)
                }
        }
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(isActive)
        .accessibilityHidden(!isActive)
        .zIndex(isActive ? 1 : 0)
    }

    @ViewBuilder
    private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .classDetail(let classRoute): ClassDetailView(route: classRoute)
        case .reservations: ReservationsView()
        case .credits: CreditsView()
        case .notifications: NotificationsView()
        case .account: AccountDetailsView()
        }
    }
}

// MARK: - Nav inset environment

enum NavInset { case horizontal, vertical }

private struct NavInsetKey: EnvironmentKey {
    static let defaultValue: NavInset = .horizontal
}

extension EnvironmentValues {
    var navInset: NavInset {
        get { self[NavInsetKey.self] }
        set { self[NavInsetKey.self] = newValue }
    }
}

extension View {
    /// Keeps scroll content clear of the floating nav.
    func floatingNavClearance() -> some View {
        modifier(FloatingNavClearance())
    }
}

private struct FloatingNavClearance: ViewModifier {
    @Environment(\.navInset) private var inset
    func body(content: Content) -> some View {
        switch inset {
        case .horizontal: content.contentMargins(.bottom, Theme.tabBarClearance, for: .scrollContent)
        case .vertical: content.contentMargins(.bottom, 32, for: .scrollContent)
                .contentMargins(.trailing, 84, for: .scrollContent)
        }
    }
}

// MARK: - Floating glass nav

struct FloatingNav: View {
    let selection: AppTab
    let vertical: Bool
    let onSelect: (AppTab) -> Void
    @Namespace private var bubble

    var body: some View {
        let layout = vertical
            ? AnyLayout(VStackLayout(spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
        layout {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(Theme.spring) { onSelect(tab) }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 19, weight: selection == tab ? .regular : .light))
                        .symbolVariant(selection == tab ? .fill : .none)
                        .foregroundStyle(selection == tab ? Theme.ink : Theme.secondaryText)
                        .frame(width: 52, height: 52)
                        .background {
                            if selection == tab {
                                Circle()
                                    .fill(Theme.pink.opacity(0.32))
                                    .matchedGeometryEffect(id: "bubble", in: bubble)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .glass(Capsule())
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Keep swipe-back with hidden navigation bars

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

// MARK: - Shared detail chrome

/// Glass back button for pushed screens (system bar is hidden).
struct GlassBackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        GlassCircleButton(systemImage: "chevron.left", label: "Back") { dismiss() }
    }
}

/// Header for pushed text screens: glass back, optional trailing, then a Light title.
struct PushedHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                GlassBackButton()
                Spacer()
                trailing
            }
            ScreenTitle(text: title)
        }
        .padding(.top, 8)
    }
}
