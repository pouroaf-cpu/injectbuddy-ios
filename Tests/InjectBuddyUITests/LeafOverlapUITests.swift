import XCTest

/// NO TWO LEAF ELEMENTS' FRAMES INTERSECT.
///
/// The fourth mechanism in the F1 family, and the first one no existing check could
/// see. `lineLimit` truncation was banned; layout squeeze was caught by a ratio; a long
/// value beside a short unit was caught by the renderer probe. **Overlap is none of
/// those** — nothing is truncated and nothing is clipped, the text simply gets the width
/// it asks for and takes the height it wants, and draws on top of its neighbour. Every
/// truncation check in this repo is blind to it by construction.
///
/// So the invariant is geometric and names no mechanism, which is the same move that
/// turned "the displayed string contains no ellipsis" into "a value cell is never
/// narrower than its own unit": overlap IS two frames sharing pixels, and that is
/// observable from the layer already being read.
///
/// LEAVES, NOT SIBLINGS — and this is a correction worth keeping, because the sibling
/// formulation would have missed the defect it was written for. Measured on
/// `IB2245752`:
///
///     Button 'control_compound'            {{15.5, 245.5}, {371.3,  78.3}}
///       StaticText 'Oxandrolone (Anavar)'  {{83.3, 192.7}, {193.0, 183.3}}
///     StaticText 'Compound'                {{15.9, 189.3}, {216.0,  52.7}}
///
/// The two strings that draw on top of each other are `Oxandrolone (Anavar)` and
/// `Compound`, and they are NOT siblings — one is a child of the picker button, the
/// other is the button's sibling. They are an uncle and a nephew. Comparing siblings
/// only would have gone green on this frame.
/// Comparing LEAVES gets it for free and needs no ancestor/descendant exclusion either,
/// because a container is never a leaf: a child drawn inside its own parent, which is
/// the normal case, is not two leaves.
final class LeafOverlapUITests: XCTestCase {

    private var app: XCUIApplication!

    /// Elements that are DELIBERATELY over other content, declared rather than absorbed.
    /// Asserted from the other end below, so a new deliberate overlap has to be added
    /// here on purpose instead of quietly widening the exemption (BOARD §5.30, §5.32).
    /// Overlaps this suite currently FINDS, each one a debt with the finding it belongs
    /// to. Asserted from both ends: a listed pair must still overlap, and the run goes
    /// red the moment it stops so the entry gets deleted (§5.30). Matched on labels,
    /// order-insensitive.
    struct ExpectedOverlap {
        let screen: String, a: String, b: String, finding: String
        /// Set when the overlap does not reproduce on every run. The both-ends
        /// assertion is SKIPPED for these — and that is a real weakening, so it is
        /// spelled rather than implied. `result_Units (U-100)` × tab bar on
        /// Reconstitution appeared in a full three-test run and did not appear in a
        /// single-test run of the same screen at the same size, with the tab bar frame
        /// measured identical (0, 791, 402, 83) both times. Something upstream of the
        /// overlap moves — most likely which rung the pinning gate picked, since that
        /// decides whether this row is in the pinned bar or the scroll. Until that is
        /// understood the entry can suppress the failure but cannot be asserted to
        /// still occur, because asserting it would make the suite flaky, and a flaky
        /// suite cannot report a new overlap either.
        var isIntermittent: Bool = false
        /// Every entry here is an AX5 defect — none of these overlap at default size.
        /// Without this the both-ends assertion fires at default with "NO LONGER
        /// overlap", which would be true and useless: the debt has not been paid, the
        /// screen is simply not at the size where it exists.
        var isAccessibilitySize: Bool = true
        func matches(_ x: String, _ y: String) -> Bool { (a == x && b == y) || (a == y && b == x) }
    }

    // ─── THE PICKER OVERFLOW IS GONE FROM THIS LIST — T-16 ──────────────────────
    //
    // Five entries were deleted here, not suppressed, and this note is what rule 7
    // leaves behind in their place. All five were the SAME defect: `.pickerStyle(.menu)`
    // drawing its selected value outside its own chrome.
    //
    //   Steroid Dosage · `Compound` × `Oxandrolone (Anavar)`     — the measured one
    //   Steroid Dosage · `Oxandrolone (Anavar)` × `Vial strength`
    //   TRT Dose       · `Ester` × `Testosterone Enanthate`      — closed by T-01a #2
    //   TRT Dose       · `2×/week` × <tab bar>                   — the `Frequency` picker
    //   TRT Dose       · `2×/week` × `syringe`
    //
    // WHAT CHANGED, and it is why these can be deleted rather than re-measured one by
    // one: the menu picker published its value as a `StaticText` CHILD of its button,
    // which is what let it be one half of a leaf pair. `Combobox` publishes ONE
    // element with `accessibilityElement(children: .ignore)` and the value as the
    // control's `accessibilityValue`, so `Oxandrolone (Anavar)` and `2×/week` are no
    // longer leaves at all. There is nothing left to intersect.
    //
    // The two `2×/week` entries were ALREADY stale before this pass, and that is worth
    // recording rather than quietly folding in: T-01a #1 moved TRT's default mode to
    // `ndays`, and `injPerWeek` only renders under `perweek`, so the control those
    // entries name has not been on the screen at all since that commit. A both-ends
    // list only works if the entries are deleted when the debt is paid.
    static let expectedOverlaps: [ExpectedOverlap] = [
        // ─── STEROID DOSAGE AT AX5 — TEN PAIRS, NINE OF WHICH HAD NEVER BEEN SEEN ────
        //
        // These arrived in one run only because the reporting bug below was fixed first
        // (T-34): the suite used to stop after ONE pair per screen, so this screen had
        // reported exactly one overlap on every run it has ever had, and read as "one
        // problem" while carrying ten. That is the finding, not the entries.
        //
        // They split into two causes and neither is the picker overflow T-16 closed.

        // (a) THE MERGED-HUSK ARTEFACT — T-35. A control whose accessibility element is
        // a `StaticText` spanning the WHOLE control, with its own child glyphs published
        // as separate leaves inside it. NOTHING DRAWS ON ANYTHING: the magnifier sits
        // left of the value and the chevron right of it, both inside the chrome. The
        // suite's own note says "a container is never a leaf" — here the container
        // collapsed INTO a leaf, which is the case that reasoning does not cover. Both
        // glyphs carry `accessibilityHidden(true)` and it does not remove them from the
        // automation snapshot; see the note on `Combobox`.
        .init(screen: "Steroid Dosage", a: "Oxandrolone (Anavar)", b: "magnifyingglass",
              finding: "T-35 — a control's merged husk publishes its own glyphs as leaves"),
        .init(screen: "Steroid Dosage", a: "Oxandrolone (Anavar)", b: "chevron.down",
              finding: "T-35 — a control's merged husk publishes its own glyphs as leaves"),
        .init(screen: "Steroid Dosage", a: "Show result", b: "mark_see_result",
              finding: "T-35 — a control's merged husk publishes its own glyphs as leaves"),

        // (b) CONTENT UNDER THE PINNED RESULT BAR AT AX5 — T-36, and this one is real.
        // `Show result` is the pinned bar's own merged frame, 370 x 153.3 at y 506.3.
        // The compound control, the `Vial strength` label and `field_strength` itself
        // all run under it, and the label reaches on down into the tab bar. This is the
        // same family as T-20 measured at default size; at AX5 it is four elements deep
        // rather than one row straddling.
        .init(screen: "Steroid Dosage", a: "Oxandrolone (Anavar)", b: "Show result",
              finding: "T-36 — content runs under the pinned result bar at AX5"),
        // The bar's ICON as well as its frame — the compound control is deep enough
        // under the plate to reach the glyph, not just the plate's edge.
        .init(screen: "Steroid Dosage", a: "Oxandrolone (Anavar)", b: "mark_see_result",
              finding: "T-36 — content runs under the pinned result bar at AX5"),
        .init(screen: "Steroid Dosage", a: "Vial strength", b: "Show result",
              finding: "T-36 — content runs under the pinned result bar at AX5"),
        .init(screen: "Steroid Dosage", a: "field_strength", b: "Show result",
              finding: "T-36 — content runs under the pinned result bar at AX5"),
        // ONE entry, two icons — `house.fill` and `calendar` both resolve to the tab-bar
        // sentinel. Written with `tabBar` and not with the icon names the failure
        // message prints, which is the trap this file already documents: `describe()`
        // prints the raw key while the matcher compares the resolved one.
        .init(screen: "Steroid Dosage", a: "Vial strength", b: LeafOverlapUITests.tabBar,
              finding: "T-36 — content draws into the tab bar at AX5"),
        // A 0.7pt graze against the raised hero. Listed rather than dismissed — §5.5
        // exists because a 12.7pt overlap was once read as "grazing".
        .init(screen: "Steroid Dosage", a: "unit_strength", b: "syringe",
              finding: "T-36 — content collides with the raised hero at AX5"),

        // CONTENT REACHES INTO THE TAB BAR at AX5.
        // The NAMED CONTENT element reaches into the TAB BAR — one finding, not one per
        // icon. Listing each collision separately was tried and is the wrong shape: the
        // overflowing string is wide enough to cross the whole row, so every entry
        // revealed another icon and the list grew without the debt growing. The content
        // side stays enumerated, because that is the thing that is wrong; the tab bar is
        // treated as the single region it is. This is NOT "exempt anything that overlaps
        // the tab bar" — an unnamed element landing there still fails.
        .init(screen: "Reconstitution", a: "result_Add bac water", b: LeafOverlapUITests.tabBar,
              finding: "BOARD §1 — content draws into the tab bar at AX5"),
        // CONTENT COLLIDES WITH THE RAISED HERO at AX5. `MainShell.heroOverhang` is 22pt
        // and reserves space for the circle so scrolled content clears it; at large text
        // that reservation is not enough. Two screens, and the Reconstitution one is a
        // 0.7pt graze — listed rather than dismissed, because §5.5 exists precisely
        // because a 12.7pt overlap was once read as "grazing" off a downscaled montage.
        .init(screen: "Reconstitution", a: "Add bac water", b: "syringe",
              finding: "BOARD §1 — content collides with the raised hero at AX5"),
        .init(screen: "Reconstitution", a: "result_Add bac water", b: "syringe",
              finding: "BOARD §1 — content collides with the raised hero at AX5"),
        // DEFAULT SIZE, not AX5 — found when this suite was run at normal text purely to
        // check the AX5 debts were size-scoped correctly. §5.22: the default frames are
        // not the clean half, they are the half nobody looks at.
        //
        // ALL OF THE DEFAULT-SIZE ENTRIES ARE MARKED INTERMITTENT, and that is a measured
        // property rather than a convenience. Both of these pairs involve content near
        // the BOTTOM of a scrolling form, so whether they collide depends on where the
        // form happens to be sitting — observed present in one run and absent in the next
        // on the same screen at the same size. The suppression still holds when they
        // appear, and an UNNAMED overlap still fails, so the suite can still report a new
        // one; what is given up is the assertion that these specific two must still
        // occur. That is a real weakening and it is why it is spelled out here rather
        // than left to whoever notices the flag.
        // The raised hero circle covers the tail of the disclaimer on EVERY calculator.
        .init(screen: "Steroid Dosage", a: "Maths only — not medical advice.", b: "syringe",
              finding: "BOARD §1 — the hero covers the disclaimer tail at default size",
              isIntermittent: true, isAccessibilitySize: false),
        .init(screen: "TRT Dose", a: "Maths only — not medical advice.", b: "syringe",
              finding: "BOARD §1 — the hero covers the disclaimer tail at default size",
              isIntermittent: true, isAccessibilitySize: false),
        .init(screen: "Reconstitution", a: "Maths only — not medical advice.", b: "syringe",
              finding: "BOARD §1 — the hero covers the disclaimer tail at default size",
              isIntermittent: true, isAccessibilitySize: false),
        // A RESULT VALUE drawing into the tab bar at DEFAULT size.
        // ON ALL THREE, and it is the PINNED BAR's `Units (U-100)` row reaching into the
        // tab bar at default size — not one screen's layout. Marked intermittent because
        // it has been observed ABSENT on Reconstitution in one run and present in
        // another, with the tab bar frame identical both times; something upstream moves.
        .init(screen: "Reconstitution", a: "result_Units (U-100)", b: LeafOverlapUITests.tabBar,
              finding: "BOARD §1 — a result value draws into the tab bar at default size",
              isIntermittent: true, isAccessibilitySize: false),
        .init(screen: "Steroid Dosage", a: "result_Units (U-100)", b: LeafOverlapUITests.tabBar,
              finding: "BOARD §1 — a result value draws into the tab bar at default size",
              isIntermittent: true, isAccessibilitySize: false),
        .init(screen: "TRT Dose", a: "result_Units (U-100)", b: LeafOverlapUITests.tabBar,
              finding: "BOARD §1 — a result value draws into the tab bar at default size",
              isIntermittent: true, isAccessibilitySize: false),
    ]

    /// Sentinel for "the tab bar", resolved geometrically at check time.
    static let tabBar = "<tab bar>"

    static func expectedOverlap(_ screen: String, _ a: String, _ b: String,
                                ax: Bool) -> ExpectedOverlap? {
        expectedOverlaps.first { $0.screen == screen && $0.matches(a, b) && $0.isAccessibilitySize == ax }
    }

    static let declaredOverlays: Set<String> = [
        // The pinned bar's own frame probe: a `Color.clear` spanning the whole bar,
        // published so the reachability sweep can read the plate's top edge. It is a
        // measurement artefact, not a rendered element, and it covers everything in the
        // bar by design.
        "bar_plate",
    ]

    override func setUpWithError() throws {
        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? "", password = env["QA_PASSWORD"] ?? ""
        try XCTSkipUnless(!email.isEmpty && !password.isEmpty,
                          "TEST_RUNNER_QA_EMAIL / TEST_RUNNER_QA_PASSWORD not set.")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["QA_EMAIL"] = email
        app.launchEnvironment["QA_PASSWORD"] = password
        app.launch()
        let accept = app.buttons["I understand"]
        if accept.waitForExistence(timeout: 6) { accept.tap() }
        XCTAssertTrue(app.buttons["Dashboard"].waitForExistence(timeout: 15), "Not signed in.")
    }

    func testSteroidDosage() { check("Steroid Dosage", field: "field_mgWeek") }
    func testTRTDose() { check("TRT Dose", field: "field_mgWeek") }
    func testReconstitution() { check("Reconstitution", field: "field_targetConc") }

    // MARK: - The invariant

    private func check(_ screen: String, field: String,
                       file: StaticString = #filePath, line: UInt = #line) {
        open(screen, expecting: field)
        let nodes = Self.parse(app.debugDescription)

        // A parser that matches nothing passes silently — the same trap the folder check
        // carries. The tree for any calculator is dozens of nodes deep; single digits
        // means the format moved under us.
        XCTAssertGreaterThan(nodes.count, 20,
                             "\(screen): parsed only \(nodes.count) nodes out of the element "
                             + "tree. The debugDescription format has changed and this suite is "
                             + "measuring nothing.", file: file, line: line)

        // CONTENT-BEARING leaves only, and on screen.
        //
        // Two exclusions, both found by running this and reading what it caught rather
        // than by anticipating them:
        //
        // 1. A container whose children were removed by `accessibilityHidden` becomes a
        //    LEAF ITSELF — an unlabelled `Other` husk with the container's frame. The
        //    closed drawer is one: `Other (0.0, -1220.0, 402.0, 2011.0)`, spanning the
        //    whole screen and 1220pt above it, overlapping everything. §5.6 again from
        //    a new angle — hiding is not removing, and what is left behind here is a
        //    shape with no content.
        // 2. Anything off-screen. The same husk sits at y = -1220.
        //
        // The invariant is about things a user can SEE sharing pixels, so a node that
        // draws nothing of its own is not one of the two things. Restricting to content
        // types keeps `Compound` vs `Oxandrolone (Anavar)` — both StaticText — which is
        // the defect this exists for.
        let contentTypes: Set<String> = ["StaticText", "TextField", "SecureTextField", "Image"]
        let window = app.windows.firstMatch.frame
        let leaves = Self.leaves(of: nodes).filter { node in
            node.frame.width > 0.5 && node.frame.height > 0.5
                && !Self.declaredOverlays.contains(node.identifier)
                && contentTypes.contains(node.type)
                && window.intersects(node.frame)
        }
        XCTAssertGreaterThan(leaves.count, 5, "\(screen): \(leaves.count) leaves — too few.",
                             file: file, line: line)

        // The tab bar, as a FRAME to be contained by — not a y threshold.
        //
        // "At or below the tab bar's top edge" was the first cut and it was wrong in the
        // direction that hides defects: content which has overflowed PAST that line gets
        // relabelled as tab-bar furniture and stops being the thing under test. It
        // swallowed `Ester` / `Testosterone Enanthate` at y 862.7 — the picker overflow
        // itself, running off the bottom of an 874pt display. Containment keeps the real
        // tab items (wholly inside the bar) and leaves overflowing content as content.
        let tabBarFrame = Self.parse(app.debugDescription)
            .first { $0.type == "TabBar" }?.frame ?? .null
        XCTAssertFalse(tabBarFrame.isNull, "\(screen): no TabBar node in the tree.",
                       file: file, line: line)
        // BOTH ENDS on the region itself. A region defined by a node is only as
        // trustworthy as the node, and the first cut of this collapsing rule failed by
        // EATING THE EVIDENCE — content that had overflowed past the tab bar stopped
        // being under test. So the region is pinned: it spans the full width, sits at
        // the bottom of the window, and is a bar rather than a panel. If the TabBar node
        // ever reports something larger, this fails instead of quietly swallowing more.
        XCTAssertEqual(tabBarFrame.width, window.width, accuracy: 1.0,
                       "\(screen): TabBar is \(tabBarFrame.width)pt wide against a "
                       + "\(window.width)pt window — that is not the tab bar.",
                       file: file, line: line)
        XCTAssertEqual(tabBarFrame.maxY, window.maxY, accuracy: 1.0,
                       "\(screen): TabBar does not end at the bottom of the window.",
                       file: file, line: line)
        XCTAssertLessThan(tabBarFrame.height, window.height * 0.2,
                          "\(screen): TabBar is \(tabBarFrame.height)pt tall — the region "
                          + "has grown and is now absorbing content it should be testing.",
                          file: file, line: line)

        // Ancestor chain of every `syringe` glyph, to settle whether the element in the
        // tree is the raised hero (which carries accessibilityHidden(true)) or a second
        // glyph somewhere else. That distinction decides whether §5.6's sweep was WRONG
        // or merely INCOMPLETE, and they need different fixes.
        for (i, node) in nodes.enumerated() where node.key.contains("syringe") {
            var chain: [String] = ["\(node.type)'\(node.key)'\(node.frame)"]
            var depth = node.depth
            for j in stride(from: i - 1, through: 0, by: -1) where nodes[j].depth < depth {
                chain.append("\(nodes[j].type)'\(nodes[j].key)'\(nodes[j].frame)")
                depth = nodes[j].depth
                if chain.count > 6 { break }
            }
            print("SYRINGE \(screen) :: " + chain.reversed().joined(separator: " > "))
        }

        // Read from the app's own gate probe — the same witness the reachability sweep
        // uses, and not the thing under test here.
        let gate = app.descendants(matching: .any).matching(identifier: "bar_gate").firstMatch
        XCTAssertTrue(gate.exists, "\(screen): bar_gate absent — cannot tell what size this is.",
                      file: file, line: line)
        let isAX = gate.label.contains("ax=true")

        var knownSeen: Set<String> = []
        var declaredSeen: Set<String> = []
        for node in nodes where Self.declaredOverlays.contains(node.identifier) {
            declaredSeen.insert(node.identifier)
        }

        // COLLECTED, THEN FAILED ONCE — T-34, and it was costing real runs.
        //
        // This loop used to `XCTFail` per pair with a `reported >= 6` cap, "enough to
        // diagnose; the rest is noise". `continueAfterFailure = false` in `setUp` means
        // the FIRST `XCTFail` ends the test, so the cap was unreachable and every run
        // reported EXACTLY ONE pair per screen. Two consecutive T-16 runs each came back
        // with a single pair, fixed it, and had to be run again to see the next one — on
        // a rig where a UI run is minutes and is shared with every other agent.
        //
        // Worse than the cost: one pair reads as "one problem" when it means "at least
        // one problem". `continueAfterFailure` stays FALSE — a failed navigation must
        // still stop the run before it measures the wrong screen — and the reporting is
        // what changes.
        var unexpected: [String] = []
        for i in leaves.indices {
            for j in leaves.index(after: i)..<leaves.endIndex {
                let a = leaves[i], b = leaves[j]
                let overlap = a.frame.intersection(b.frame)
                // Touching edges are not overlap. A nav bar button whose bottom is the
                // title's top shares a line and no pixels.
                guard overlap.width > 0.5 && overlap.height > 0.5 else { continue }
                // Either element may be resolved to the tab-bar sentinel, so a named
                // content element colliding with any part of that row is one debt.
                let aKey = tabBarFrame.contains(a.frame) ? Self.tabBar : a.key
                let bKey = tabBarFrame.contains(b.frame) ? Self.tabBar : b.key
                let key = "\(aKey)|\(bKey)"
                if let known = Self.expectedOverlap(screen, aKey, bKey, ax: isAX) {
                    knownSeen.insert(key)
                    _ = known
                    continue
                }
                unexpected.append("""
                      \(a.describe())
                      \(b.describe())
                      shared region \(overlap)
                    """)
            }
        }
        XCTAssertTrue(unexpected.isEmpty, """
            \(screen): \(unexpected.count) PAIR(S) OF ELEMENTS DRAW IN THE SAME PIXELS.
            \(unexpected.joined(separator: "\n"))
            Nothing is truncated and nothing is clipped here — one view took the height it \
            wanted and drew over its neighbour. No truncation check can see this.
            """, file: file, line: line)

        // Both ends. A listed overlap that has stopped overlapping is a debt that has
        // been paid and an entry that is now suppressing a real assertion.
        for known in Self.expectedOverlaps
        where known.screen == screen && known.isAccessibilitySize == isAX
              && !known.isIntermittent {
            XCTAssertTrue(knownSeen.contains("\(known.a)|\(known.b)")
                          || knownSeen.contains("\(known.b)|\(known.a)"),
                          "\(screen): `\(known.a)` and `\(known.b)` NO LONGER overlap "
                          + "(\(known.finding)). Delete the entry from `expectedOverlaps`.",
                          file: file, line: line)
        }

        // ...and the exemption asserted from the other end: an entry that never appears
        // is exempting nothing and hiding that it exempts nothing.
        for declared in Self.declaredOverlays {
            XCTAssertTrue(declaredSeen.contains(declared),
                          "\(screen): `declaredOverlays` names `\(declared)` and it is not in "
                          + "the tree. Stale entry.", file: file, line: line)
        }
        print("OVERLAP \(screen): \(leaves.count) leaves, no intersections.")
    }

    // MARK: - Tree parsing

    struct Node {
        let depth: Int
        let type: String
        let identifier: String
        let label: String
        let frame: CGRect
        /// ONE name, used by `describe()` AND by the expected-overlap matcher.
        /// They were different for one round: `describe()` preferred the identifier
        /// while the matcher compared labels, so an entry written from a failure message
        /// (`house.fill`, the tab icon's identifier) could never match the thing it was
        /// written for (`home`, its label). A list keyed differently from the messages
        /// people copy into it is a list that silently never matches.
        var key: String { identifier.isEmpty ? label : identifier }
        func describe() -> String {
            let name = key.isEmpty ? type : "\(type) '\(key)'"
            return "\(name) \(frame)"
        }
    }

    /// `      StaticText, 0x…, {{15.9, 189.3}, {216.0, 52.7}}, identifier: 'x', label: 'y'`
    static func parse(_ dump: String) -> [Node] {
        let frameRE = try! NSRegularExpression(
            pattern: #"^(\s*)→?\s*(\w+)[^,]*,[^,]*,\s*\{\{([-\d.]+), ([-\d.]+)\}, \{([-\d.]+), ([-\d.]+)\}\}"#)
        let idRE = try! NSRegularExpression(pattern: #"identifier: '([^']*)'"#)
        let labelRE = try! NSRegularExpression(pattern: #"label: '([^']*)'"#)

        return dump.split(separator: "\n").compactMap { raw -> Node? in
            let line = String(raw)
            let ns = line as NSString
            guard let m = frameRE.firstMatch(in: line, range: NSRange(location: 0, length: ns.length))
            else { return nil }
            func g(_ i: Int) -> String { ns.substring(with: m.range(at: i)) }
            let ident = idRE.firstMatch(in: line, range: NSRange(location: 0, length: ns.length))
                .map { ns.substring(with: $0.range(at: 1)) } ?? ""
            let label = labelRE.firstMatch(in: line, range: NSRange(location: 0, length: ns.length))
                .map { ns.substring(with: $0.range(at: 1)) } ?? ""
            return Node(depth: g(1).count,
                        type: g(2),
                        identifier: ident,
                        label: label,
                        frame: CGRect(x: Double(g(3))!, y: Double(g(4))!,
                                      width: Double(g(5))!, height: Double(g(6))!))
        }
    }

    /// A node is a leaf when the next node in document order is not deeper than it.
    static func leaves(of nodes: [Node]) -> [Node] {
        nodes.enumerated().filter { i, node in
            i + 1 >= nodes.count || nodes[i + 1].depth <= node.depth
        }.map(\.element)
    }

    // MARK: - Navigation

    private func open(_ name: String, expecting field: String) {
        let tabs = app.buttons.matching(identifier: "Tools")
        XCTAssertTrue(tabs.firstMatch.waitForExistence(timeout: 8), "No Tools tab.")
        tabs.allElementsBoundByIndex.filter { $0.isHittable }
            .max { $0.frame.midY < $1.frame.midY }?.tap()

        var row: XCUIElement?
        for _ in 0..<12 {
            row = app.staticTexts.matching(identifier: name).allElementsBoundByIndex
                .first { $0.isHittable }
            if row != nil { break }
            (app.collectionViews.allElementsBoundByIndex + app.tables.allElementsBoundByIndex
             + app.scrollViews.allElementsBoundByIndex)
                .first { $0.isHittable && $0.frame.minX >= 0 }?.swipeUp()
        }
        guard let hit = row else { return XCTFail("\(name) never became hittable.") }
        hit.tap()
        XCTAssertTrue(app.textFields[field].waitForExistence(timeout: 8),
                      "Tapped \(name) and did not land on it.")
    }
}
