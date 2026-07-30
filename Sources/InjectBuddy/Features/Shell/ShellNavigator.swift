import SwiftUI

// ─── ShellNavigator ──────────────────────────────────────────────────────────
// The shell's shared navigation state. Injected as an @EnvironmentObject so any
// screen can drive navigation, the drawer and the log sheet with a stable API:
//
//   @EnvironmentObject var navigator: ShellNavigator
//   navigator.openDrawer()                     // hamburger
//   navigator.selectTab(.calendar)             // bottom bar
//   navigator.select(.calendar)                // drawer / iPad sidebar (route, not tab)
//   navigator.push(.calculator(.trt))          // push onto the CURRENT tab's stack
//   navigator.presentLogSheet()                // the raised hero
//   navigator.goToDashboard()                  // after a flow completes
//
// One NavigationPath PER TAB rather than one shared path. With a single path, a
// calculator pushed from Add would also show up on Dashboard when you switched to it,
// and switching tabs would drop you wherever the other tab had wandered.

@MainActor
final class ShellNavigator: ObservableObject {
    /// The selected bottom tab (iPhone). Never `.log` — that slot opens a sheet.
    @Published var tab: MainTab = .dashboard
    /// A stack per tab, keyed by tab.
    @Published var paths: [MainTab: NavigationPath] = [:]
    @Published var isDrawerOpen = false
    @Published var isLogSheetPresented = false

    /// The root route of the current tab. Used by the drawer's selection highlight and
    /// by the iPad split view, both of which think in routes rather than tabs.
    var route: AppRoute { tab.route ?? .dashboard }

    // MARK: Tabs

    func selectTab(_ tab: MainTab) {
        guard tab != .log else { return presentLogSheet() }
        // Tapping the tab you are already on pops it to its root — the standard iOS
        // affordance, and the only way out of a deep stack without repeated swiping.
        if self.tab == tab {
            paths[tab] = NavigationPath()
        } else {
            self.tab = tab
        }
        closeDrawer()
    }

    func pathBinding(for tab: MainTab) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in self?.paths[tab] ?? NavigationPath() },
            set: { [weak self] in self?.paths[tab] = $0 }
        )
    }

    // MARK: Routes

    /// Select a ROOT destination (drawer / iPad sidebar). Routes that own a tab switch
    /// to it; everything else — a calculator, Settings — pushes onto the current tab,
    /// which is what lets the drawer act as a launcher rather than a second navigation
    /// system competing with the bar.
    func select(_ route: AppRoute) {
        switch route {
        case .dashboard: selectTab(.dashboard)
        case .calendar:  selectTab(.calendar)
        case .tools:     selectTab(.tools)
        case .add:       selectTab(.add)
        default:         push(route)
        }
        closeDrawer()
    }

    func push(_ route: AppRoute) {
        var path = paths[tab] ?? NavigationPath()
        path.append(route)
        paths[tab] = path
        closeDrawer()
    }

    /// Unwind to the Dashboard root — where a completed Add flow lands, matching the
    /// web's redirect to /account/ once the start day is confirmed.
    func goToDashboard() {
        paths[.add] = NavigationPath()
        tab = .dashboard
        paths[.dashboard] = NavigationPath()
        closeDrawer()
    }

    // MARK: Drawer + sheets

    func openDrawer()   { withAnimation(Theme.drawerAnimation) { isDrawerOpen = true } }
    func closeDrawer()  { withAnimation(Theme.drawerAnimation) { isDrawerOpen = false } }
    func toggleDrawer() { withAnimation(Theme.drawerAnimation) { isDrawerOpen.toggle() } }

    func presentLogSheet() {
        closeDrawer()
        isLogSheetPresented = true
    }
}
