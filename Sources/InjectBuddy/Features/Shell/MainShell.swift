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
    @StateObject private var keyboard = KeyboardObserver()

    /// AUDIT FINDING F14: the stock unselected tab item measured **2.77:1** over
    /// the bar (#929299 on #F2F2F7) and **2.63:1** over card content — under the
    /// 3:1 that WCAG 1.4.11 requires for a glyph, and well under the 4.5:1 its
    /// ~10pt label needs. It read as disabled rather than merely inactive.
    ///
    /// UITabBarAppearance is the only way to reach these — SwiftUI exposes no
    /// modifier for the unselected item colour.
    ///   unselected #5C5C66 → 5.92:1
    ///   selected   #075E56 → 6.86:1  (never #0FBCAD, which is 2.13:1 here)
    /// Selection is also carried by weight, not colour alone: semibold → bold.
    init() {
        let unselected = UIColor(red: 0x5C / 255, green: 0x5C / 255, blue: 0x66 / 255, alpha: 1)
        let selected = UIColor(red: 0x07 / 255, green: 0x5E / 255, blue: 0x56 / 255, alpha: 1)

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = unselected
            item.normal.titleTextAttributes = [
                .foregroundColor: unselected,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            ]
            item.selected.iconColor = selected
            item.selected.titleTextAttributes = [
                .foregroundColor: selected,
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
            ]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
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
                        .tabItem { tabLabel(for: tab) }
                        .tag(tab)
                }
            }
            // The hero is drawn OVER the bar rather than being a tab item, because a
            // tab item cannot break the bar's top plane. The real tap target stays the
            // tab item underneath — see tabSelection — so the raised circle is pure
            // decoration and VoiceOver reads one genuine control, not a duplicate.
            // Hidden while the keypad is up. The overlay reanchors to the new
            // bottom edge — which is the focused screen's own pinned CTA — and
            // rendered the primary action as an unlabelled teal rectangle
            // (audit finding F2). It has no job while the tab bar is covered.
            .overlay(alignment: .bottom) {
                if !keyboard.isVisible { heroButton }
            }

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

    /// How far the raised hero rises ABOVE the tab bar's top edge.
    ///
    /// The system gives every scroll view an inset for the tab bar, but knows
    /// nothing about a circle we drew on top of it, so content scrolled to its
    /// bottom ran underneath the hero — on the calculator it landed on the "Add"
    /// CTA (F2), and on the dashboard it clipped the fourth protocol card. A button
    /// drawn over another button is the worst version of that, because both look
    /// tappable and only one is.
    ///
    /// z-order does not fix this. Stacking the hero above content only decides who
    /// wins the collision; reserving space is what stops there being one. So this is
    /// added as a bottom safe-area inset on every tab's content, which every
    /// ScrollView, List and safeAreaInset inside then composes with automatically.
    ///
    /// Measured rather than derived: on the built app the tab bar's top hairline sits
    /// at pt 771.3 and the hero assembly (circle + 4pt ring + shadow) starts at
    /// pt ~753, so it overhangs by ~18pt. 22 matches the lift constant below and
    /// leaves a little margin.
    static let heroOverhang: CGFloat = 22

    /// The centre slot gets its TITLE ONLY — no icon.
    ///
    /// Giving every tab `Label(title, systemImage:)` meant the log slot rendered its
    /// own syringe glyph, and `heroButton` was then drawn over it. The circle did not
    /// fully cover the glyph: a sliver of the plunger protruded below the circle's
    /// bottom edge, directly above the "Log dose" label, so the slot read as two
    /// buttons — one of them a fragment. That is exactly what it looked like.
    ///
    /// Dropping the icon removes the second glyph rather than hiding it. Enlarging
    /// the circle to cover it would have been tuning a collision instead of deleting
    /// one, and would re-break at any Dynamic Type size that moves either piece.
    ///
    /// Everything else is unchanged and deliberate: the tab item is still the real
    /// tap target (`tabSelection` bounces `.log` into the sheet), the text label
    /// stays so the slot matches its four neighbours, and VoiceOver still sees one
    /// control — the circle remains `accessibilityHidden`.
    @ViewBuilder
    private func tabLabel(for tab: MainTab) -> some View {
        if tab == .log {
            Text(tab.title)
        } else {
            Label(tab.title, systemImage: tab.icon)
        }
    }

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
            // Reserves the hero's overhang for EVERY screen in this tab, pushed
            // screens included, instead of each one remembering to pad for it.
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: Self.heroOverhang)
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
            // The FAB stays TEAL — the PWA's does, and the fill is brand identity.
            // What changed is the GLYPH: it was white on #0FBCAD, which is 2.38:1,
            // the same failure fixed everywhere else and then left sitting on the
            // most prominent control in the app. Navy on teal is 6.63:1 and is
            // brand-colour-on-brand-colour rather than an invented pairing.
            .fill(Theme.accent)
            .frame(width: 54, height: 54)
            .overlay(
                Image(systemName: MainTab.log.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.navy)
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
