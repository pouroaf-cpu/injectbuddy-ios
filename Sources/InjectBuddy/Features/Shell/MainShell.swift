import SwiftUI

// ─── MainShell ───────────────────────────────────────────────────────────────
// The authed container.
//
// iPhone: a five-slot bottom bar — Dashboard · Calendar · LOG DOSE (raised hero) ·
// Tools · Add — matching the web's ib-bottomnav.js. Built on a real TabView rather
// than a hand-rolled bar (operator's call): each tab keeps its own NavigationStack,
// and safe-area insets, VoiceOver, Dynamic Type and the swipe-back gesture all come
// from the system instead of being re-implemented.
//
// The off-canvas drawer SURVIVES behind the hamburger, exactly as on web where the
// burger still opens the rail alongside the bottom bar. It is how you reach all 14
// calculators and Settings without those having to become tabs.
//
// iPad: unchanged — a persistent NavigationSplitView sidebar. A bottom tab bar on a
// 13" canvas would be wrong, and the sidebar already shows every destination at once.

struct MainShell: View {
    @StateObject private var navigator = ShellNavigator()
    @EnvironmentObject private var network: NetworkMonitor
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        Group {
            if hSize == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .environmentObject(navigator)
        .sheet(isPresented: $navigator.isLogSheetPresented) {
            LogDoseSheet()
                .environmentObject(navigator)
        }
    }

    // MARK: iPhone — bottom tabs + drawer

    private var iPhoneLayout: some View {
        ZStack(alignment: .leading) {
            TabView(selection: tabSelection) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    tabStack(for: tab)
                        .tabItem { Label(tab.title, systemImage: tab.icon) }
                        .tag(tab)
                }
            }
            // The hero is drawn OVER the bar rather than being a tab item, because a
            // tab item cannot break the bar's top plane. The real tap target stays the
            // tab item underneath — see tabSelection — so the raised circle is pure
            // decoration and VoiceOver reads one genuine control, not a duplicate.
            .overlay(alignment: .bottom) { heroButton }

            drawerLayer

            offlineBannerLayer
        }
    }

    // MARK: Offline banner (all layouts)

    /// Global connectivity pill. Lives in its own GeometryReader (same pattern as
    /// drawerLayer's width calc below) so the bottom padding clears the REAL tab
    /// bar height — system row + whatever home-indicator safe area this device has
    /// — instead of a device-specific guess. Sits above the bar, never on top of
    /// it, and `allowsHitTesting(false)` because it is status-only: it must never
    /// steal a tap meant for the tab bar underneath.
    private var offlineBannerLayer: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                if !network.isOnline {
                    OfflineBanner()
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.bottom, geo.safeAreaInsets.bottom + Self.tabBarRowHeight)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .animation(Theme.drawerAnimation, value: network.isOnline)
        .allowsHitTesting(false)
    }

    /// Standard iOS compact tab bar row height. The home-indicator safe area on
    /// top of this comes from GeometryReader above, not hardcoded.
    private static let tabBarRowHeight: CGFloat = 49

    /// Each tab owns a NavigationStack, so pushing a calculator from Add does not
    /// disturb Dashboard's stack and switching tabs preserves where you were.
    @ViewBuilder
    private func tabStack(for tab: MainTab) -> some View {
        if let route = tab.route {
            NavigationStack(path: navigator.pathBinding(for: tab)) {
                RouteContent(route: route)
                    .navigationDestination(for: AppRoute.self) { pushed in
                        RouteContent(route: pushed, showsHamburger: false)
                    }
            }
        } else {
            // `log` has no screen. It is never actually selected — the binding below
            // bounces it — so this exists only to give the slot a tab item.
            Color.clear
        }
    }

    /// Selecting the middle slot opens the log sheet and leaves the current tab where
    /// it was: the slot is an action, not a destination.
    private var tabSelection: Binding<MainTab> {
        Binding(
            get: { navigator.tab },
            set: { picked in
                if picked == .log {
                    navigator.presentLogSheet()
                } else {
                    navigator.selectTab(picked)
                }
            }
        )
    }

    private var heroButton: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: 54, height: 54)
            .overlay(
                Image(systemName: MainTab.log.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .overlay(Circle().stroke(Theme.background, lineWidth: 4))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            // Lifts the circle so its top half clears the bar, mirroring the web's
            // --ib-bn-lift. allowsHitTesting(false) lets the tap fall through to the
            // real tab item, so there is one control here rather than two.
            .offset(y: -22)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Drawer (iPhone only)

    private var drawerLayer: some View {
        GeometryReader { geo in
            let drawerWidth = min(320, geo.size.width * 0.84)

            ZStack(alignment: .leading) {
                if navigator.isDrawerOpen {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { navigator.closeDrawer() }
                        .accessibilityLabel("Close menu")
                }

                DrawerView()
                    .frame(width: drawerWidth)
                    .frame(maxHeight: .infinity)
                    .background(Theme.background)
                    // +24 so the shadow clears the screen edge when closed.
                    .offset(x: navigator.isDrawerOpen ? 0 : -(drawerWidth + 24))
                    .shadow(color: .black.opacity(navigator.isDrawerOpen ? 0.25 : 0), radius: 16, x: 4)
            }
            .gesture(edgeAndDragGesture(drawerWidth: drawerWidth))
        }
        // Closed, this layer covers the whole screen and would otherwise swallow every
        // tap meant for the tab bar underneath it.
        .allowsHitTesting(navigator.isDrawerOpen)
    }

    /// Swipe-from-left-edge to open; swipe-left on the open drawer to close.
    private func edgeAndDragGesture(drawerWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onEnded { value in
                let dx = value.translation.width
                let startX = value.startLocation.x
                if !navigator.isDrawerOpen, startX < 24, dx > 60 {
                    navigator.openDrawer()
                } else if navigator.isDrawerOpen, dx < -60 {
                    navigator.closeDrawer()
                }
            }
    }

    // MARK: iPad — split view

    private var iPadLayout: some View {
        // No bottom tab bar on iPad, so the same banner rides at the top instead —
        // still non-blocking (allowsHitTesting(false)) and out of the sidebar/detail
        // content's way.
        ZStack(alignment: .top) {
            NavigationSplitView {
                DrawerList(selection: Binding(
                    get: { navigator.route },
                    set: { navigator.select($0) }
                ))
                .navigationTitle("InjectBuddy")
            } detail: {
                NavigationStack(path: navigator.pathBinding(for: navigator.tab)) {
                    RouteContent(route: navigator.route, showsHamburger: false)
                        .navigationDestination(for: AppRoute.self) { pushed in
                            RouteContent(route: pushed, showsHamburger: false)
                        }
                }
            }

            if !network.isOnline {
                OfflineBanner()
                    .padding(.top, Theme.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(Theme.drawerAnimation, value: network.isOnline)
    }
}
