import SwiftUI

struct MainTabView: View {
    @State private var router = Router()
    @State private var store = StudioStore()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $router.selectedTab) {
                Tab(value: AppTab.schedule) {
                    NavigationStack(path: $router.schedulePath) {
                        ScheduleView()
                            .navigationDestination(for: ClassRoute.self) { ClassDetailView(route: $0) }
                    }
                    .toolbar(.hidden, for: .tabBar)
                }
                Tab(value: AppTab.bookings) {
                    NavigationStack(path: $router.bookingsPath) {
                        MyBookingsView()
                            .navigationDestination(for: ClassRoute.self) { ClassDetailView(route: $0) }
                    }
                    .toolbar(.hidden, for: .tabBar)
                }
                Tab(value: AppTab.account) {
                    NavigationStack {
                        AccountView()
                    }
                    .toolbar(.hidden, for: .tabBar)
                }
            }

            if router.isTabBarVisible {
                FloatingTabBar(selection: $router.selectedTab)
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Theme.spring, value: router.isTabBarVisible)
        .ignoresSafeArea(.keyboard)
        .environment(router)
        .environment(store)
    }
}

/// Floating, translucent pill tab bar.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(Theme.spring) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .symbolVariant(selection == tab ? .fill : .none)
                        Text(tab.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == tab ? Theme.ink : Theme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        if selection == tab {
                            Capsule()
                                .fill(Theme.softPink.opacity(0.6))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .modifier(GlassCapsule())
        .padding(.horizontal, 36)
        .sensoryFeedback(.selection, trigger: selection)
    }
}
