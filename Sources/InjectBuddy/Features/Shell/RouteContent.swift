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
                    // The PWA header is a NAVY FILLED SQUARE either side of a centred
                    // teal wordmark. Most of navy's 33 uses across that design are
                    // these two buttons, and the pair is the screen's signature — a
                    // bare tinted glyph in the corner is most of why the iOS build
                    // read as generic. 44x44pt, so they also clear the HIG floor the
                    // old bare Image did not.
                    ToolbarItem(placement: .topBarLeading) {
                        NavySquareButton(systemImage: "line.3.horizontal", label: "Menu") {
                            navigator.openDrawer()
                        }
                    }
                    ToolbarItem(placement: .principal) { BrandWordmark() }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavySquareButton(systemImage: "square.and.pencil", label: "Edit protocols") {
                            navigator.selectTab(.add)
                        }
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
        case .tools:
            ToolsScreen()
        case .add:
            AddScreen()
        case .addCategory(let category):
            AddCategoryScreen(category: category)
        case .addConfirm(let dosageId):
            ConfirmStartScreen(dosageId: dosageId)
        case .settings:
            SettingsScreen()
        case .calculator(let slug):
            CalculatorScreen(slug: slug)
        }
    }
}

// MARK: - PWA header furniture

/// Filled navy square with a white glyph — the PWA's icon-button treatment.
struct NavySquareButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: Theme.minTarget, height: Theme.minTarget)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Theme.navy)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Centred teal wordmark with the syringe glyph, replacing the plain system title.
struct BrandWordmark: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "syringe.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
            // foregroundColor, not foregroundStyle: the Text-returning overload
            // needed for `+` concatenation is iOS 17+, and this app targets 16.
            Text("inject").foregroundColor(Theme.tealTextStrong)
            + Text("buddy").foregroundColor(Theme.tealTextStrong).bold()
        }
        .font(.system(size: 17, weight: .semibold))
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("injectbuddy")
    }
}
