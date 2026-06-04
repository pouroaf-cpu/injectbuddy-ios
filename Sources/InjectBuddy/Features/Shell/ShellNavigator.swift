import SwiftUI

// ─── ShellNavigator ──────────────────────────────────────────────────────────
// The shell's shared navigation state. Injected as an @EnvironmentObject so any
// screen can drive navigation and the drawer with a stable API:
//
//   @EnvironmentObject var navigator: ShellNavigator
//   navigator.openDrawer()                  // hamburger
//   navigator.select(.calendar)             // replace the root screen (from the drawer)
//   navigator.push(.calculator(.trt))       // push onto the current stack (e.g. "Add protocol")

@MainActor
final class ShellNavigator: ObservableObject {
    /// The current root screen (what the drawer selects).
    @Published var route: AppRoute = .dashboard
    /// Pushed routes layered on top of the root (e.g. dashboard → a calculator).
    @Published var path = NavigationPath()
    @Published var isDrawerOpen = false

    func select(_ route: AppRoute) {
        self.route = route
        path = NavigationPath()
        closeDrawer()
    }

    func push(_ route: AppRoute) {
        path.append(route)
        closeDrawer()
    }

    func openDrawer() { withAnimation(Theme.drawerAnimation) { isDrawerOpen = true } }
    func closeDrawer() { withAnimation(Theme.drawerAnimation) { isDrawerOpen = false } }
    func toggleDrawer() { withAnimation(Theme.drawerAnimation) { isDrawerOpen.toggle() } }
}
