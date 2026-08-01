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
                    // Filled square either side of a centred teal wordmark — the
                    // PWA's header signature, and 44x44pt so it also clears the HIG
                    // floor the old bare toolbar Image did not.
                    // Recoloured navy -> teal on request. See the note on
                    // TealSquareButton for why it is #0A9D90 and not the brand teal.
                    ToolbarItem(placement: .topBarLeading) {
                        TealSquareButton(systemImage: "line.3.horizontal", label: "Menu") {
                            navigator.openDrawer()
                        }
                    }
                    ToolbarItem(placement: .principal) { BrandWordmark() }
                    ToolbarItem(placement: .topBarTrailing) {
                        TealSquareButton(systemImage: "square.and.pencil", label: "Edit protocols") {
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

/// Filled teal square with a white glyph — the PWA's icon-button treatment.
///
/// The teal is `tealText` #0A9D90, NOT the brand `accent` #0FBCAD. White on #0FBCAD
/// is 2.38:1 and fails outright, and anything lighter fails harder — white on
/// #5FE8DA is roughly 1.2:1. #0A9D90 measures 3.37:1, which clears the 3:1 WCAG
/// 1.4.11 asks of an icon, and is the lightest teal in the palette that white can
/// legally sit on. If a lighter square is ever wanted, the glyphs have to stop being
/// white and become dark ink (#101018 on #0FBCAD is 7.95:1) — lighter AND white is
/// not an available combination.
struct TealSquareButton: View {
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
                    RoundedRectangle(cornerRadius: 12).fill(Theme.tealText)
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
