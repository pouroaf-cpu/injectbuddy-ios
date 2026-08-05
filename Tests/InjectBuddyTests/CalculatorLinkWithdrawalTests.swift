import XCTest
@testable import InjectBuddy

/// H6 — BMI and Free T Index are withdrawn from every route in, and the screens stay.
///
/// The owner's words are the whole specification: *"leave them alone, and don't let the
/// links to it go anywhere, we will work on later."* Two halves, and each one can be
/// satisfied while the other is broken, so both are asserted:
///
///   1. **No browse surface offers a withdrawn calculator.** Removed, not disabled.
///   2. **Nothing about a withdrawn calculator has been deleted.** It keeps its spec,
///      its category membership and its saved-protocol identity, so re-enabling is
///      deleting a case from one switch. A test that only checked (1) would go green on
///      someone ripping the slug out of the enum, which is the opposite of the order.
///
/// **WHY THIS IS A UNIT TEST AND WHAT IT IS NOT.** It asserts the MODEL the screens
/// read. It cannot see a screen that stops reading the model — a `ForEach` restating
/// `allCases` inline is exactly how `DashboardScreen` came to offer all fifteen — so it
/// is paired with a photograph of the Tools list, not trusted instead of one. §5.33: the
/// aim is `CalculatorSlug`, `CalculatorCategory` and `NavItems`, at the model level, on
/// every surface that reads them.
///
/// **THE RED-RUN ACCOUNT THAT WAS HERE WAS WRONG, AND THE CORRECTION IS THE POINT.**
/// This file previously claimed it had been falsified by pointing `DashboardScreen` at
/// `CalculatorSlug.allCases`, and quoted the failure message it produced. That break was
/// re-run on 2026-08-03 and **all seven tests stayed green.** The quoted failure has
/// never occurred.
///
/// The reason is visible in `browseSurfaces` below. Three of the four entries name a real
/// model expression the app enumerates — `CalculatorCategory.members` (ToolsScreen),
/// `savableMembers` (AddCategoryScreen), `NavItems.calculators` (DrawerView) — and those
/// are genuinely coupled: change the screen's source and the entry changes with it.
/// **The dashboard entry is not.** That dialog builds its `ForEach` inline, so there is
/// no expression to name, and the entry falls back to `CalculatorSlug.listedCases` —
/// the filter under test. It asks the filter whether the filter ran, and it cannot
/// disagree.
///
/// So the diagnosis in this comment was right and the fix was never made. That is the
/// worse of the two: a check that names its own blind spot and then reports it closed.
///
/// **What is actually shown red, and it was re-run rather than inherited:** emptying the
/// withdrawn set trips `testTheWithdrawnSetIsNotEmpty` and
/// `testWithdrawnSetIsExactlyTheTwoTheOwnerNamed` — two failures, both naming the set.
/// The bypass case is covered by `CalculatorLinkWithdrawalUITests`, against the running
/// screen, because it cannot be covered from here.
final class CalculatorLinkWithdrawalTests: XCTestCase {

    /// The withdrawal, restated here rather than read from the code under test.
    /// `XCTAssertEqual(x, x)` is a check that cannot fail, and this project has found
    /// eight of those. If someone withdraws a third calculator, this line is where they
    /// say so out loud.
    private let expectedWithdrawn: Set<CalculatorSlug> = [.bmi, .freeTestIndex]

    // MARK: - The withdrawal itself

    func testWithdrawnSetIsExactlyTheTwoTheOwnerNamed() {
        XCTAssertEqual(Set(CalculatorSlug.withdrawnCases), expectedWithdrawn,
                       "The withdrawn set has changed. H6 withdrew BMI and Free T Index "
                       + "and nothing else — Cycle Plotter cannot save either and stays "
                       + "reachable deliberately.")
    }

    /// An exemption that exempts nothing hides that it exempts nothing (§5.32). Every
    /// assertion below is satisfied trivially by an empty withdrawn set, so the set
    /// being non-empty is asserted before any of them are believed.
    func testTheWithdrawnSetIsNotEmpty() {
        XCTAssertFalse(CalculatorSlug.withdrawnCases.isEmpty,
                       "Nothing is withdrawn, so every assertion in this file passes by "
                       + "having no work to do.")
    }

    // MARK: - 1. No route in

    /// **`unlistedCases` — the UNION of withdrawn and collapsed — because this test is
    /// about absence from browse, whatever the reason for it.** The two invariant tests
    /// below are the ones that must distinguish them.
    ///
    /// Naming it rather than re-deriving `filter { !$0.isListed }` inline is not style:
    /// repointing the other tests at `withdrawnCases` left `unlistedCases` read by
    /// nothing, and `scripts/unread-decls.py` — the T-47 sweep, minutes old — caught it.
    /// A declaration nobody reads is silence, not an error, and this file is where the
    /// silence would have been.
    func testNoBrowseSurfaceOffersAWithdrawnCalculator() {
        let absent = Set(CalculatorSlug.unlistedCases)
        for surface in Self.browseSurfaces {
            let leaked = surface.offered.filter { absent.contains($0) }
            XCTAssertTrue(leaked.isEmpty,
                          "\(surface.surface) still links to \(leaked.map(\.title).joined(separator: ", "))"
                          + " — H6 withdrew them from every route in, not from the Tools list only.")
        }
    }

    /// From the other end. A withdrawal that spreads is as wrong as one that does not
    /// happen: every calculator still listed has to be reachable from somewhere, or the
    /// filter has quietly eaten a screen nobody has missed yet.
    func testEveryListedCalculatorIsOfferedSomewhere() {
        let reachable = Set(Self.browseSurfaces.flatMap(\.offered))
        for slug in CalculatorSlug.listedCases {
            XCTAssertTrue(reachable.contains(slug),
                          "\(slug.title) is listed but no browse surface offers it — it "
                          + "is unreachable without being withdrawn, which is the state "
                          + "nobody notices.")
        }
    }

    /// `Cycle Plotter` is the live instance of the case above, and it is worth naming so
    /// a reader does not read the previous test as "everything is in Tools". No category
    /// claims the plotter, so `ToolsScreen` cannot render it; its only routes are the
    /// dashboard dialog and the drawer. That is an OPEN FINDING on the board and H6 did
    /// not fix it — this asserts the state as it actually is, so the day it is fixed
    /// this line has to be deleted rather than silently outliving its truth.
    func testCyclePlotterIsStillMissingFromTools() {
        let inTools = CalculatorCategory.allCases.flatMap(\.members)
        XCTAssertFalse(inTools.contains(.cyclePlotter),
                       "Cycle Plotter is now in the Tools list. That is the fix for an "
                       + "open board finding — delete this test and tick the finding.")
        XCTAssertTrue(CalculatorSlug.listedCases.contains(.cyclePlotter),
                      "Cycle Plotter has been withdrawn. H7–H12 are about to be built on "
                      + "it and the spec keeps it reachable.")
    }

    // MARK: - 2. Nothing was deleted

    /// **`withdrawnCases`, NOT `unlistedCases`, and the distinction is load-bearing.**
    /// T-12 collapsed EOD, which is unlisted for a different reason: its category
    /// membership is gone and there is no screen to put back. Sweeping it in here would
    /// have forced this test to be relaxed — and the invariants below are the entire
    /// content of a *withdrawal*, so relaxing them would leave the file asserting
    /// nothing while still reporting green. `EodCollapseTests` asserts the opposite
    /// invariants for the collapsed set.
    func testAWithdrawnCalculatorKeepsItsScreenSpecAndIdentity() {
        for slug in CalculatorSlug.withdrawnCases {
            // Still in the enum, so a saved row of this type still decodes into a screen
            // rather than into nil. Production has none today; the type still exists.
            XCTAssertTrue(CalculatorSlug.allCases.contains(slug),
                          "\(slug.title) was removed from CalculatorSlug. H6 withdrew the "
                          + "links, not the calculator.")

            // Still renders. An empty field list is a screen that draws nothing.
            let spec = CalculatorCatalog.spec(for: slug)
            XCTAssertFalse(spec.fields.isEmpty,
                           "\(slug.title) has no fields left — its screen would render empty.")
            XCTAssertFalse(spec.savedType.isEmpty,
                           "\(slug.title) lost its saved_dosages.calculator_type string.")

            // Still belongs to its category, so re-listing it is one switch case and not
            // an archaeology exercise.
            let owners = CalculatorCategory.allCases.filter { $0.allMembers.contains(slug) }
            XCTAssertEqual(owners.count, 1,
                           "\(slug.title) should belong to exactly one category so it can "
                           + "be put back; it belongs to \(owners.count).")
        }
    }

    /// The CTA gate is a separate mechanism and H6 does not replace it. The spec says so
    /// in those words: removing the links makes the BMI write *unreachable*, not *fixed*,
    /// and `cyclePlotter` is still reachable with `canSaveProtocol` false.
    func testWithdrawalDidNotQuietlyBecomeTheSaveGate() {
        XCTAssertFalse(CalculatorSlug.cyclePlotter.canSaveProtocol,
                       "Cycle Plotter can suddenly save a protocol.")
        XCTAssertTrue(CalculatorSlug.cyclePlotter.isListed,
                      "Cycle Plotter is listed AND cannot save — that pairing is the "
                      + "reason `isListed` is not `canSaveProtocol` under another name.")
        for slug in CalculatorSlug.withdrawnCases {
            XCTAssertFalse(slug.canSaveProtocol,
                           "\(slug.title) is withdrawn but reports it can save a protocol.")
        }
    }

    // MARK: - The surfaces

    /// Every expression an app screen enumerates to offer a calculator, named with the
    /// screen that reads it. Restating them here is the coupling this test is made of:
    /// a screen that stops reading the model is invisible from a unit test, which is why
    /// the Tools list is also photographed.
    private struct BrowseSurface {
        let surface: String
        let offered: [CalculatorSlug]
    }

    private static let browseSurfaces: [BrowseSurface] = [
        // ToolsScreen — the browse tab.
        .init(surface: "CalculatorCategory.members (ToolsScreen)",
              offered: CalculatorCategory.allCases.flatMap(\.members)),
        // AddCategoryScreen — step two of the Add funnel.
        .init(surface: "CalculatorCategory.savableMembers (AddCategoryScreen)",
              offered: CalculatorCategory.allCases.flatMap(\.savableMembers)),
        // DashboardScreen — the "Add a protocol" confirmation dialog.
        .init(surface: "CalculatorSlug.listedCases (DashboardScreen dialog)",
              offered: CalculatorSlug.listedCases),
        // DrawerView — live on iPhone, and the surface the H6 spec did not name.
        .init(surface: "NavItems.calculators (DrawerView)",
              offered: NavItems.calculators.compactMap {
                  if case .calculator(let slug) = $0 { return slug }
                  return nil
              }),
    ]
}
