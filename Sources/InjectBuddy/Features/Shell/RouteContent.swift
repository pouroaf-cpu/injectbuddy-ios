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
                    // See NavySquareButton for why these are navy and not the tint
                    // a hierarchy argument briefly put here.
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

/// Filled NAVY square with a white glyph — the PWA's icon-button treatment, 15.79:1.
///
/// These went teal for one cycle on a "navigation chrome should recede" argument.
/// That is a sound general principle and it is not what this brand does: the PWA's
/// header buttons are navy, and navy there is BOTH chrome and CTA (33 uses spanning
/// the header buttons, the NavyCard CTAs, and section labels). The brand is the
/// spec, so it wins over the principle — and this pair is what made the side-by-side
/// read as the same app in the first place.
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
