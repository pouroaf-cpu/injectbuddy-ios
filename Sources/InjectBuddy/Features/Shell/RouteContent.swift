import SwiftUI

// ─── RouteContent ────────────────────────────────────────────────────────────
// Maps an AppRoute to its screen. This is the contract between the shell and the
// feature screens: each screen exposes the initializer named here.
//   • DashboardScreen()              — Features/Dashboard
//   • CalendarScreen()               — Features/Calendar
//   • SettingsScreen()               — Features/Settings
//   • CalculatorScreen(slug:)        — Features/Calculators
// A hamburger that opens the drawer is attached here so every root screen gets one.

struct RouteContent: View {
    let route: AppRoute
    /// Root screens get a hamburger; pushed screens get the system back button instead.
    var showsHamburger: Bool = true

    @EnvironmentObject private var navigator: ShellNavigator

    var body: some View {
        screen
            .navigationTitle(route.title)
            .navigationBarTitleDisplayMode(route == .dashboard ? .inline : .automatic)
            .toolbar {
                if showsHamburger {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { navigator.openDrawer() } label: {
                            Image(systemName: "line.3.horizontal")
                        }
                        .accessibilityLabel("Menu")
                    }
                }
            }
    }

    @ViewBuilder
    private var screen: some View {
        switch route {
        case .dashboard:
            DashboardScreen()
        case .calendar:
            CalendarScreen()
        case .settings:
            SettingsScreen()
        case .calculator(let slug):
            CalculatorScreen(slug: slug)
        }
    }
}
