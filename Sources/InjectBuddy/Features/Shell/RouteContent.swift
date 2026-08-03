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
            // KEPT, AND NEVER CLEARED — including on the routes below that do not draw
            // it. `.navigationTitle` is also the BACK-CONTROL LABEL for anything pushed
            // from this screen, and the calculator pushes `.addConfirm` off its own Add
            // button. Clearing the title to remove the duplicate would trade two titles
            // for a back control reading "Back" on the confirm step of the app's primary
            // write path. So the title stays and only its RENDERING is suppressed.
            .navigationTitle(route.title)
            .navigationBarTitleDisplayMode(titleDisplayMode)
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
                } else if carriesOwnHeader {
                    // THE SUPPRESSION. A `.principal` item REPLACES the navigation
                    // bar's title view, so an empty one leaves the bar with its back
                    // control and nothing else — and the title above survives for the
                    // back control of the next screen. It is paired with `.inline` in
                    // `titleDisplayMode` and only works paired: a LARGE title is drawn
                    // in its own area below the bar and a title view does not suppress
                    // it.
                    //
                    // Zero-sized and `accessibilityHidden`, per §5.39 — a `Color.clear`
                    // put in the tree as furniture is a real element the harness and
                    // VoiceOver both read, and the one that was attached as an
                    // `.overlay` made the primary CTA of every calculator report
                    // `hittable=false`.
                    ToolbarItem(placement: .principal) {
                        Color.clear
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                }
            }
    }

    /// Routes that draw their OWN title inside the content area, so the inherited
    /// navigation title would be a second title on the same screen.
    ///
    /// ONE SITE, all fourteen calculators. `CalculatorScreen` carried an interim
    /// `.navigationBarTitleDisplayMode(.inline)` for this and its own comment said the
    /// real fix was shared and not in that file — demoting the duplicate only made it
    /// smaller. `DESIGN-PARITY §9` option (a) put the calculator's name in the content
    /// area (`ScreenHeader`) precisely because a wrapping title in `.principal` clips
    /// its third line with no ellipsis; this is the other half of that decision.
    ///
    /// `.cyclePlotter` IS EXCLUDED AND IT IS ENUMERATED, not derived. That slug routes
    /// through `CalculatorScreen` and renders `CyclePlotterScreen`, which has no
    /// `ScreenHeader` — suppressing its navigation title would leave that screen with
    /// no title at all rather than with one.
    private var carriesOwnHeader: Bool {
        if case let .calculator(slug) = route { return slug != .cyclePlotter }
        return false
    }

    /// `.inline` on the dashboard (its greeting is the heading) and on any route that
    /// draws its own header; `.automatic`, i.e. a large title, everywhere else.
    ///
    /// The large title on a calculator is the element measured truncating to
    /// `Steroid Dos…` at AX5 on `IB2245752`. It goes with the duplicate.
    private var titleDisplayMode: NavigationBarItem.TitleDisplayMode {
        route == .dashboard || carriesOwnHeader ? .inline : .automatic
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
