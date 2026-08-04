import SwiftUI

// ─── CalculatorScreen ────────────────────────────────────────────────────────
// Generic calculator form driven entirely by a CalculatorSpec. Renders each field
// from the spec, pins a ONE-ROW action bar via .safeAreaInset(edge: .bottom), and
// saves the inputs as a protocol. The cycle-plotter slug routes to its bespoke
// screen instead.
//
// `SPEC-RESULT-SHEET-AND-SYRINGE.md §1`, the owner's decision of 2026-08-03, and it
// reverses `RESULT-PANEL-SPEC.md §4`. What used to be pinned here was the whole
// `ResultCard`, behind a five-rung measured gate that chose how much of it to show.
// The gate was right about its own arithmetic and wrong about the shape of the
// problem: a panel whose FLOOR is a result card is still a panel, and it measured
// 52.40% of the content area at default type size on TRT. That single fact was the
// cause of six findings — F-H, the four buried barrel buttons, F-I, and the
// frequency control unreachable with the keypad up, where the occluder was never the
// keyboard.
//
// So the bar no longer carries the result at all. It carries `See your result`,
// which opens the sheet, and the committing action D5 requires. The ladder, its
// candidate measurement and its cap are gone with it — there is nothing left to
// choose between, which is the point: ONE control, fifteen calculators.
//
// SCOPE OF THIS PASS: §8 build steps 1 and 2 — the bar, and the sheet with numbers.
// The syringe drawing (§3), its motion (§3.3), over-capacity colouring (§5) and zoom
// (§4) are the next stage and are sequenced that way by the spec itself, because
// each needs photographs at four barrels × two text sizes to pass.

struct CalculatorScreen: View {
    let slug: CalculatorSlug

    @EnvironmentObject private var navigator: ShellNavigator
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var network: NetworkMonitor
    @Environment(\.backend) private var backend

    @StateObject private var vm: CalculatorViewModel
    @StateObject private var keyboard = KeyboardObserver()
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Measured layout, in points, keyed by `BarMetrics`. Everything the pinning
    /// gate decides on comes from here — nothing is inferred from a type size.
    @State private var metrics: [String: CGFloat] = [:]
    /// The content area, held from the last measurement taken with the keypad DOWN.
    ///
    /// SwiftUI shrinks the safe area when the keyboard comes up, so the live
    /// measurement drops to a fraction of the screen while a field is being edited.
    /// Gating on that would unpin the result exactly when the user is typing a dose
    /// into it — the opposite of what this is for. The content area is a property of
    /// the screen, not of the keypad, so it is measured when the keypad is down.
    @State private var contentAreaAtRest: CGFloat = 0

    /// The result sheet. `SPEC-RESULT-SHEET-AND-SYRINGE §2` — a `.sheet` with detents
    /// rather than a full-screen cover, because the user is comparing the sheet
    /// against the inputs behind it and the inputs must not vanish.
    @State private var showsResult = false

    /// Which field is being edited, keyed by `CalculatorInput.key`.
    ///
    /// Hoisted out of `NumberField` so the screen — which is what owns the keyboard
    /// toolbar — can tell WHICH field's quick values to put above the keypad. See
    /// `keyboardAccessory`.
    @FocusState private var focusedKey: String?

    init(slug: CalculatorSlug) {
        self.slug = slug
        _vm = StateObject(wrappedValue: CalculatorViewModel(slug: slug))
    }

    var body: some View {
        Group {
            if slug == .cyclePlotter {
                CyclePlotterScreen()
            } else {
                form
            }
        }
    }

    private var form: some View {
        // GLP-1 specs render two pickers and a barrel; at default type that left
        // roughly a third of the screen as dead space between the last field and
        // the pinned result bar, while TRT's five fields filled it. Sizing the
        // stack to at least the viewport and pushing the disclaimer to the bottom
        // distributes the slack instead of pooling it in one void.
        GeometryReader { geo in
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ScreenHeader(title: slug.title)

                // `vm.fields`, NOT `vm.spec.fields` — the spec resolved into the units
                // the user has selected (T-41). Identity is still the field key, so the
                // resolution cannot re-create a field or lose its editing state.
                ForEach(vm.fields) { field in
                    if shouldShow(field) {
                        FieldRow(field: field, vm: vm, focusedKey: $focusedKey)
                    }
                }

                // The in-scroll card, which renders EVERY row unconditionally and is
                // now the only card on the screen at rest. The pinned copy is gone
                // (see the header comment), so `result_<label>` addresses exactly one
                // element again without the surface-following rule the gate forced —
                // there is only one surface.
                //
                // NOT DELETED in favour of the sheet, deliberately. The sheet is a
                // second reading surface, not a replacement: `result.isValid` here is
                // what the user sees while typing, and removing it would make the live
                // result — the reason this is not the PWA's "Show result" flow —
                // reachable only through a modal.
                if vm.result.isValid {
                    ResultCard(result: vm.result, barrelMl: barrelMl)
                }

                // T-01a #3. Position copied from the web, which is not incidental:
                // `PlotProtocolCTA`'s own comment places it "between the result value
                // and the FUNNEL-2 Save CTA". It reads as "and now look at this over
                // time", which only works after the number it is offering to plot.
                if PlotLevelsCTA.shows(slug) {
                    PlotLevelsCTA(slug: slug, resultValid: vm.result.isValid) {
                        // T-17 — the link carries the calculator's values now.
                        //
                        // `PlotterSeed.from` is the web's own `mapDosage`, per branch,
                        // and it RETURNS NIL where iOS cannot honestly draw the
                        // compound — a peptide with no named molecule, HCG, a blend.
                        // Those fall through to the unseeded route, which is the
                        // behaviour that shipped and is what the web does in every
                        // case: `?from=<calcId>` is read by nothing on the plotter
                        // side. See the note on `PlotterSeed`.
                        if let seed = PlotterSeed.from(slug: slug, values: vm.values) {
                            navigator.push(.plotter(seed: seed))
                        } else {
                            navigator.push(.calculator(.cyclePlotter))
                        }
                    }
                }

                // T-01a #4. Last thing before the disclaimer, exactly as the web
                // orders it — `TwoColCalcPage` renders `CalcFormula` beneath the FAQ,
                // above the footer.
                FormulaCard(slug: slug)

                Spacer(minLength: Theme.Spacing.md)

                Text("Maths only — not medical advice.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .padding(Theme.Spacing.md)
            // MINUS THE PLATE. `geo` is read OUTSIDE the ScrollView, so
            // `geo.size.height` is the WHOLE content area — including the band the
            // pinned plate covers. Sizing the stack to that told a short form to fill
            // space it cannot be seen in: the stack's own bottom, and therefore the
            // disclaimer the Spacer pushes there, landed BEHIND the plate at rest.
            // Measured, on Reconstitution, unscrolled: disclaimer y 761.67 against a
            // plate top of 671.0 and a content area running 152.33…791.0 — i.e. the
            // stack ended exactly at 791, the bottom of the area the plate occupies
            // the last ~120pt of. That is also where the hero circle sits (F-F).
            //
            // `§5.4` / D2: whatever pins a surface reserves the space it occupies,
            // where it is pinned. The bar's own RENDERED height is already measured
            // (`BarMetrics.bar`, published by the `measure` in `resultBar`), so this
            // is the measured number rather than a constant somebody re-tunes later.
            .frame(minHeight: max(0, geo.size.height - plateReservation), alignment: .top)
        }
        // ON THE SCROLLVIEW, not on the GeometryReader outside it. This is the
        // difference between the form scrolling UNDER the bar and the form being
        // clipped above it, and until T21 it made no visible difference because the
        // plate was near-opaque.
        //
        // Attached outside, the ScrollView is laid out in the reduced region, so the
        // area behind the plate contains NOTHING — and a material with no backdrop
        // does not blur, it resolves to a flat slab. Measured: `.ultraThinMaterial`
        // there sampled #767676 at four different scroll positions, identical to the
        // byte, which is what "there is nothing behind this" looks like in a number.
        // It also came out DARKER than the `.bar` slab it replaced (#D9D9D9), because
        // the thinner the material the more it shows of a backdrop that is not there.
        .safeAreaInset(edge: .bottom) { resultBar }
        }
        .background(Theme.canvas)
        // The content area is measured OUT HERE, outside the inset, because
        // this is the only position whose height is the region between the fixed
        // header and the tab bar. Verified against the framebuffer rather than read
        // off the modifier chain: this proxy reports 638.67pt while a band profile of
        // the same frame puts the header bottom at 152.33pt and the tab bar's top
        // hairline at 790.67pt — 638.34pt. Three safe-area insets are nested on this
        // screen (the tab bar's, MainShell.heroOverhang, and this screen's own pinned
        // bar) and a GeometryProxy one level in reports 296pt, which is the form's
        // remaining room and not the denominator anyone means by "the content area".
        .background { measure(BarMetrics.contentArea) }
        .onPreferenceChange(BarMetricsKey.self) { metrics = $0 }
        .overlay { gateProbe }
        // H5, built as `DESIGN-PARITY §9` OPTION (a) — the branded header lives in the
        // CONTENT AREA (see `ScreenHeader`), never in `.principal`.
        //
        // NOTHING IN THIS FILE TOUCHES NAVIGATION CHROME ANY MORE, and that is the
        // point. The interim that stood here — `.navigationBarTitleDisplayMode(.inline)`
        // — demoted the inherited title so the duplicate was smaller rather than gone,
        // and its own comment said the real fix was shared and not in this file. It now
        // is: `RouteContent` decides from `carriesOwnHeader` whether a route draws its
        // own title, one site for all fourteen calculators, and suppresses the inherited
        // one there while keeping `.navigationTitle` for the back control. Find it by
        // the string `carriesOwnHeader`.
        //
        // `SPEC-RESULT-SHEET-AND-SYRINGE §2`. Detents, not a full-screen cover: the
        // user is reading the sheet AGAINST the inputs behind it.
        .sheet(isPresented: $showsResult) {
            ResultSheet(result: vm.result,
                        barrelMl: barrelMl,
                        title: slug.title)
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { keyboardAccessory } }
        .onAppear { vm.scale = settings.syringeScale }
        .onChange(of: settings.syringeScale) { vm.scale = $0 }
        .onChange(of: metrics) { latest in
            guard !keyboard.isVisible, let area = latest[BarMetrics.contentArea], area > 0 else { return }
            contentAreaAtRest = area
        }
    }

    // MARK: - Keyboard accessory
    //
    // MEASURED DEFECT, 2026-08-02: with the keypad up, the focused field's
    // quick-value row is not reachable. The occluding element is NOT the keyboard —
    // it is the pinned result bar, which sits above the keyboard and covers the
    // strip the chips are in. Weekly dose is the SECOND field on the TRT screen and
    // its chips were already behind the bar; every field below it is worse. A
    // XCUITest tap on `quick_mgWeek_400` reported success and moved nothing.
    //
    // Collapsing the bar further was the other candidate and is the wrong trade: the
    // live result is the reason this screen isn't the PWA's "Show result" flow. The
    // toolbar puts the chips above the keyboard by construction, so it cannot depend
    // on where a field happens to sit in the form.
    //
    // It also supplies the only way out of a `.decimalPad`, which has no return key —
    // before this, dismissing the keypad meant tapping some other control.

    @ViewBuilder
    private var keyboardAccessory: some View {
        // A DIFFERENT identifier namespace from the in-scroll row on purpose. Both
        // rows exist in the tree while editing, and two elements answering to
        // `quick_mgWeek_400` is an ambiguous query, which fails at resolution
        // without ever reaching the assertion.
        if let key = focusedKey,
           // Resolved (T-41): the chips above the keypad must be the same five values,
           // in the same unit, as the row under the field. Reading `spec.fields` here
           // would put mcg chips over a field in mg.
           let field = vm.fields.first(where: { $0.key == key }),
           !field.quick.isEmpty {
            QuickValueRow(key: key,
                          values: field.quick,
                          unit: Self.unit(of: field),
                          selection: vm.numberBinding(key),
                          idPrefix: "kb_quick_")
            // The chip row is a horizontal ScrollView and takes the full width, so
            // the Spacer below collapses to nothing and Done ends up touching the
            // last chip. This is the gap.
            .padding(.trailing, Theme.Spacing.sm)
        }
        Spacer()
        // `kb_done` answers to TWO elements and nothing on this side removes the
        // second one. Measured: an Other at (348.0, 539.0, 38.0, 44.0) — the label's
        // natural width — and a Button at (345.0, 539.0, 44.0, 44.0), the min-target
        // frame. Putting the identifier first instead of last changed nothing;
        // `accessibilityElement(children: .ignore)` changed nothing, to the pixel.
        // A keyboard `ToolbarItemGroup` bridges each item to a UIKit bar button, and
        // the identifier is published on both the bridged control and the hosted
        // SwiftUI content. So the TEST names the element type for this one control
        // (see `unique(_:type:)`), rather than the app pretending to a uniqueness it
        // does not have. `children: .ignore` is kept because it is still the right
        // VoiceOver shape — one control, one stop — not because it fixed this.
        Button {
            focusedKey = nil
        } label: {
            Text("Done")
                .font(Theme.Typeface.cardMeta.weight(.semibold))
                .foregroundStyle(Theme.tealTextStrong)
                .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Done")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("kb_done")
    }

    private static func unit(of field: CalculatorInput) -> String? {
        if case let .number(unit, _, _, _) = field.kind { return unit }
        return nil
    }

    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }

    /// Chosen barrel capacity in mL, when this calculator renders the control.
    private var barrelMl: Double? {
        guard vm.spec.fields.contains(where: { $0.key == "syringeMl" }) else { return nil }
        let v = vm.values.number("syringeMl")
        return v > 0 ? v : nil
    }

    // BMI shows metric or imperial fields depending on the toggle.
    private func shouldShow(_ field: CalculatorInput) -> Bool {
        if slug == .bmi {
            let imperial = vm.values.bool("imperial")
            switch field.key {
            case "heightCm", "weightKg": return !imperial
            case "heightFt", "heightIn", "weightLb": return imperial
            default: return true
            }
        }
        return showsUnderMode(field)
    }

    /// T-01a #1 — which fields the chosen MODE asks for.
    ///
    /// Driven by the spec carrying a `mode` field rather than by `slug == .trt`, so
    /// the next calculator to gain the switch gets this for free instead of adding a
    /// branch here. A spec with no `mode` field shows everything, which is every
    /// calculator today except TRT.
    ///
    /// The three branches mirror `CalculatorEngine.trt` exactly, and they have to:
    /// a field the engine does not read is a field the user can set and watch do
    /// nothing, and on this screen "does nothing" is indistinguishable from "did
    /// something I did not notice". `ml2mg` is the one worth reading twice — the
    /// weekly dose is an OUTPUT there (`weeklyTotal = mgPerInj × freq`), so showing
    /// its input would be offering to set a number the engine is about to overwrite.
    private func showsUnderMode(_ field: CalculatorInput) -> Bool {
        guard vm.spec.fields.contains(where: { $0.key == "mode" }) else { return true }
        let mode = vm.values.string("mode")
        switch field.key {
        case "nDays":      return mode == "ndays"
        case "injPerWeek": return mode == "perweek" || mode == "ml2mg"
        case "mlDrawn":    return mode == "ml2mg"
        case "mgWeek":     return mode != "ml2mg"
        default:           return true
        }
    }

    /// How much vertical room the pinned plate takes out of the content area, from the
    /// renderer rather than from arithmetic. 0 until the first measurement lands, which
    /// is the pre-existing behaviour and settles on the next layout pass.
    ///
    /// WHAT THIS IS NOT, stated because the batch-2 item that produced it asked a
    /// different question and the answer matters more than the change. **The plate is a
    /// `safeAreaInset`, not an overlay** — `.safeAreaInset(edge: .bottom) { resultBar }`
    /// on the ScrollView above — and it DOES reserve its space in the scroll: on TRT the
    /// capture harness walked the form to its scroll end and the disclaimer, the last
    /// element in the stack, stopped at y 653 against a plate top of 671, i.e. the
    /// ScrollView's own bottom content inset held the content clear of the plate. So the
    /// barrel's at-rest straddle (`control_syringeMl_0.5 mL (50u)`, y 642.67…686.67,
    /// plate top 671.0) is NOT a missing reservation, and no clearance value applied
    /// here can move it: `syringeMl` is the LAST field of a form whose earlier fields
    /// already fill the viewport, so at rest it lands across the bottom edge wherever
    /// that edge is. Shrinking the plate by 28pt moves the straddle from the second of
    /// the four column rows to the third; it does not remove it.
    /// The thing that removes it is the row branch being chosen at default size again —
    /// four 44pt rows becoming one — and `ViewThatFits` refused it because it compared
    /// the labels' UNWRAPPED single-line ideal width while the row would render them
    /// wrapped and tightened. **That fit-test finding is now FIXED, at `SegmentedRow`,
    /// and this paragraph is left standing because it is the diagnosis the fix came
    /// from.** See `MinimumWidthAsIdeal` below: the row candidate reports the width it
    /// would really render at, so the comparison is like for like. `lineLimit` was not
    /// re-added — that reintroduces the truncation D4 forbids on a value+unit pair —
    /// and no ideal width was nudged until the branch flipped, which is tuning a
    /// collision.
    private var plateReservation: CGFloat { metrics[BarMetrics.bar] ?? 0 }

    private var resultBar: some View {
        barBody
            // The bar's own RENDERED height, published so the pass condition in
            // `SPEC-RESULT-SHEET-AND-SYRINGE §8` — "no more than one row, reported as a
            // percentage of the content area" — is a number the app produces rather
            // than one the harness infers from a screenshot. Paired with
            // `BarMetrics.contentArea` in `gateProbeLabel`.
            .background { measure(BarMetrics.bar) }
            // Clears the raised hero, which otherwise rests ON this CTA.
            //
            // MainShell.heroOverhang cannot do this. An outer safeAreaInset reaches
            // SCROLLED content — which is why all eight screens verified clean — but
            // it cannot lift a sibling inset pinned further in, and this bar is pinned
            // by the `.safeAreaInset(edge: .bottom)` on the ScrollView above. Proven,
            // not assumed: raising heroOverhang 22 -> 38 moved this button by exactly
            // zero pixels. So the clearance has to be added where the bar is placed.
            //
            // 16 = the measured 12.7pt overlap (button bottom pt 774.7 vs ring top
            // pt 762.0) plus ~3pt of daylight, because touching is what we are
            // removing. Padding, not a frame: it grows the background with the
            // content, and it cannot affect how the rows inside lay out — F1's reflow
            // is untouched. Inside `barBody` so the candidates measure it too.
            //
            // T21 — .bar was a near-opaque slab that read as furniture covering the
            // form rather than as a surface floating over it. `.ultraThinMaterial`
            // and NOT a hand-rolled colour with an opacity: a fixed colour at fixed
            // alpha does not adapt, does not blur, and would put us back where the
            // greeting shimmer died — a translucent overlay whose contrast depends on
            // whatever happens to be behind it, with no system machinery keeping it
            // legible.
            .background(Self.plateMaterial)
            // The plate's own frame, addressable. The reachability assertion needs the
            // TOP EDGE of this thing to ask whether any control straddles it, and
            // deriving it as "tab bar top minus whichever candidate height the gate
            // chose" would be asserting against the gate's own arithmetic — the proxy
            // checking itself. This is the rendered frame.
            //
            // `.background`, NOT `.overlay`, AND THAT IS THE WHOLE OF FINDING F-K.
            // As an overlay this `Color.clear` was an accessibility element laid ON TOP
            // of the entire bar — including the `Add` button inside it — so the
            // accessibility layer reported the primary CTA of every calculator as
            // `hittable=false`, and `AXScrollToVisible` on it failed with
            // `kAXErrorCannotComplete`. That is not a cosmetic complaint: VoiceOver and
            // Switch Control reach that button through exactly the layer that was
            // reporting it unreachable.
            // A background is proposed the same size, so `bar_plate.frame` — the only
            // thing this probe exists to publish — is byte-identical, and it no longer
            // sits over the control.
            .background {
                Color.clear
                    .accessibilityElement()
                    .accessibilityIdentifier("bar_plate")
                    .accessibilityLabel("Result bar")
            }
            // The blur alone does not say "the thing above scrolls". At the lighter
            // material the plate edge against #FAFAFB canvas is a ~2-value step and
            // the boundary effectively disappears — measured, see below. A hairline
            // restores it without reintroducing a slab.
            .overlay(alignment: .top) { plateBoundary }
    }

    /// Which system material the plate uses.
    ///
    /// Overridable in DEBUG because the choice had to be MEASURED, not picked from
    /// the documentation: `.ultraThinMaterial` — the obvious reading of "transparent
    /// with a light blur" — resolved DARKER than the near-opaque `.bar` it replaced,
    /// which is the opposite of what the names suggest. Sweeping them against the
    /// framebuffer was the only way to find that out, and leaving the hook in means
    /// the next person can re-run the sweep instead of re-deriving it.
    static var plateMaterial: Material {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["PLATE_MATERIAL"] {
        case "ultraThin": return .ultraThinMaterial
        case "thin": return .thinMaterial
        case "regular": return .regularMaterial
        case "thick": return .thickMaterial
        case "bar": return .bar
        default: break
        }
        #endif
        // .regularMaterial. NOT chosen from the documentation — chosen off the
        // measured ladder, which runs opposite to what the names promise:
        //   ultraThin #767676 · thin #D3D3D3 · bar #DBDBDB · regular #FEFEFE · thick #FFFFFF
        // `.ultraThinMaterial`, the obvious reading of "transparent with a light
        // blur", is 101 values DARKER than the near-opaque `.bar` it was meant to
        // lighten. Thickness describes how much backdrop shows through, not how light
        // the result is, so over a dark or absent backdrop the thin end is the dark
        // end. Never pick one of these by its name.
        return .regularMaterial
    }

    /// One device pixel, whatever the scale, so it reads as a rule rather than a bar.
    private var plateBoundary: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 1 / UIScreen.main.scale)
            .accessibilityHidden(true)
    }

    /// THE BAR. One definition, no states to choose between, fifteen calculators —
    /// which is the whole of `SPEC-RESULT-SHEET-AND-SYRINGE §1`.
    ///
    /// Two controls, and they are not the same kind of thing. `See your result` opens a
    /// reading surface and commits nothing. `Add` writes a protocol. The spec puts the
    /// first in the bar and says the second "stays where the app already puts it" —
    /// here — because D5 makes the committing action mandatory and wholly visible (so
    /// it cannot move into the scroll) and the spec explicitly refuses to move it into
    /// the sheet: *"the sheet is for reading, not committing. One commit path, not
    /// two."*
    ///
    /// `ViewThatFits` chooses the axis, and it chooses by LAYOUT rather than by a
    /// Dynamic Type category. That is not tidiness: `if isAccessibilitySize` is the
    /// exact guess the retired gate was retired for, and it guessed wrong in the
    /// direction that mattered. Here the fit test is real because a
    /// `.frame(maxWidth: .infinity)` reports its CHILD's ideal width when proposed
    /// `nil` — so the row branch's ideal is the sum of two actual strings, while the
    /// pills still expand to equal widths when the row is chosen. Reverse that (put a
    /// `.fixedSize` around the pill, or an `idealWidth: .infinity` anywhere in the
    /// chain) and the ideal becomes unbounded, the fit test can never succeed, and the
    /// stacked branch renders at every size — silently, which is the failure mode this
    /// project keeps finding.
    ///
    /// NEITHER CONTROL IS EVER HIDDEN OR RESIZED BY VALIDITY. A bar that changes height
    /// when the result becomes valid re-introduces the shear it was built to remove:
    /// the plate edge would move under the user's finger as they finish typing a dose.
    /// `See your result` is therefore always enabled and the sheet carries the
    /// "Enter values to calculate" state itself.
    @ViewBuilder
    private var barBody: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // DEBUG-ONLY, and it exists so the reachability sweep can still be SHOWN to
            // fail (BOARD §5.24). That suite's documented red-proof was
            // `TEST_RUNNER_BAR_SHARE_CAP=0.55`, which forced the retired gate to approve
            // the full-height bar and went red on the sheared `Frequency` picker. The
            // gate is gone, so that hook would now do NOTHING and the suite would be
            // green either way — a green indistinguishable from an absence, on the one
            // check that observes the defect this change removes.
            //
            // So the hook is re-pointed rather than deleted: it restores the pinned
            // result card and reproduces the 52% panel. `BAR_SHARE_CAP` is honoured as a
            // legacy alias at any value, so the invocation printed in
            // `PinnedBarReachabilityUITests` keeps working without editing that suite.
            if Self.forcedPinnedResultForRegressionTest, vm.result.isValid {
                // Its own identifier namespace, and out of the accessibility tree: this
                // is a reproduction of a defect, not a second place to read a dose.
                ResultCard(result: vm.result, barrelMl: barrelMl, idPrefix: "pinned_result_")
                    .accessibilityHidden(true)
            }

            // T-01a #11 — THE RESULT AFFORDANCE, and this is a layout change as much
            // as a colour one.
            //
            // WHAT WAS WRONG: a pale teal `See your result` SHARING A ROW with a navy
            // `Add`. Two controls of equal size and competing colours, so nothing on
            // the bar said which one the screen wants you to press. The web has no
            // such competition — its bar is one full-bleed bright cyan `Show result`,
            // and saving lives in the bottom nav's Add slot.
            //
            // WHAT THIS IS: the cyan bar as the web has it, full width and alone on
            // its line, with `Add` demoted underneath. `Add` does NOT move into the
            // sheet and does not leave the screen — D5 makes the committing action
            // mandatory and wholly visible, and SPEC-RESULT-SHEET-AND-SYRINGE refuses
            // it explicitly: *"the sheet is for reading, not committing. One commit
            // path, not two."* So the two stop competing by stacking rather than by
            // one of them being taken away.
            //
            // The `ViewThatFits` that used to choose the axis is gone with the
            // competition: there is no longer a row to fall back FROM.
            VStack(spacing: Theme.Spacing.sm) {
                seeResultButton
                addButton
            }

            if !network.isOnline {
                Text("You're offline — the calculator still works, but adding this as a protocol needs a connection.")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryLabel)
                    .multilineTextAlignment(.center)
            }

            if case let .failed(msg) = vm.saveState {
                Text(msg).font(.caption).foregroundStyle(Theme.danger)
            }
        }
        .padding(Theme.Spacing.md)
        .padding(.bottom, Self.heroClearance)
        .frame(maxWidth: .infinity)
    }

    /// The control the owner asked for by name: *"we need somewhere where it says click
    /// here to see your result, page slides out."*
    ///
    /// Deliberately NOT the primary treatment — navy is the committing colour app-wide
    /// (`PrimaryButton`, the hero), and a reading action wearing the writing colour on a
    /// dosing screen is a category error that costs a wrong tap. Teal on `accentSoft`
    /// at 7.65:1.
    private var seeResultButton: some View {
        Button {
            showsResult = true
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                // No frozen size. The Tools-at-AX5 finding is partly "icons that stayed
                // small while the text went huge" — inheriting the label's font is what
                // stops that being reintroduced here.
                Image(systemName: "eye.fill")
                    // THE OTHER HALF OF THE SAME COLLISION, and this one is an EXACT
                    // string match: `Image(systemName: "syringe")`, the same symbol the
                    // hero draws, added by the same pass that added `ScreenHeader`'s
                    // mark and present on every calculator too. Which of the two the
                    // sweep actually resolved is not knowable from here — that is a
                    // question for the run — so both are named rather than guessing at
                    // the one, because leaving either unnamed leaves the query
                    // ambiguous and costs another 22 frames. Same treatment, same
                    // reasons: see `ScreenHeader`'s mark for why the label goes as well
                    // as the identifier and why `accessibilityHidden` is not the fix.
                    .accessibilityIdentifier("mark_see_result")
                    .accessibilityLabel(Text(verbatim: ""))
                    .accessibilityHidden(true)
                // The web's words. `Show result` rather than `See your result` —
                // same action, and matching the label means a user who learned the
                // web is not looking for a control that has been renamed.
                Text("Show result")
                    // Wraps rather than truncating.
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.headline.weight(.bold))
            // NAVY ON CYAN, and neither half of that is free choice. #00FFEE is
            // 1.35:1 against white and cannot carry text at all; navy #001D5C on it
            // measures 12.7:1. The reference frame draws the label dark for the same
            // reason the Theme forbids `accent` as a text colour.
            .foregroundStyle(Theme.navy)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.ctaCyan)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("cta_see_result")
        .accessibilityLabel("Show result")
        .accessibilityAddTraits(.isButton)
    }

    private var addButton: some View {
            // Titled "Add" to match the web, where the bottom nav's Add slot owns
            // saving. Kept ON the calculator for now rather than moved to the tab bar:
            // that needs the calculator to publish its readiness up to the shell (the
            // iOS analogue of the web's html.ib-add-ready), which is TASK 15 proper.
            // Success no longer jumps to the dashboard — it goes to confirm the start
            // day, which otherwise silently defaults to today.
            // Offline gates the SAVE only — never the maths. Evaluation is pure and
            // local, so the inputs and the result card stay fully live with no
            // connection; it's only persisting the protocol that needs the backend.
            //
            // `slug.canSaveProtocol` IS THE FIRST CONDITION, and it is first because it
            // is the only one that is a property of the CALCULATOR rather than of this
            // moment. Without it `Add` was live on `bmi` and `freeTestIndex`, and
            // pressing it on BMI wrote a `saved_dosages` row from a height and a weight
            // and pushed `.addConfirm`, which reads "ADDED TO YOUR PROTOCOLS" and asks
            // for the day the protocol begins "so the calendar and dose reminders line
            // up". A body measurement was given a start date and wired into a dosing
            // schedule. Driven on the device, confirmed in the database, row deleted.
            //
            // The flag is not new and neither is the intent: its own comment says it
            // exists so a calculator with no save path does not "walk the user into a
            // wall at the last step", and `AddScreen` has always filtered on it. The
            // code that was missing is this reference, on the one screen that owns the
            // button. `save(backend:)` has exactly one caller — this closure — so
            // disabling the control does close the write rather than merely hide it.
            PrimaryButton(
                title: vm.saveState == .saved ? "Added ✓" : "Add",
                isLoading: vm.saveState == .saving,
                isEnabled: slug.canSaveProtocol && vm.result.isValid && network.isOnline
            ) {
                Task {
                    await vm.save(backend: backend)
                    if vm.saveState == .saved, let id = vm.savedId {
                        navigator.push(.addConfirm(dosageId: id))
                    }
                }
            }
            // ADDRESSABLE, because until this identifier existed no assertion could
            // name this button. THE BOTTOM TAB BAR HAS AN `Add` SLOT WITH THE SAME
            // LABEL, so `buttons["Add"]` on a calculator matches two elements and
            // resolves to whichever the tree happens to yield — and the tab item is
            // always enabled and always hittable. Any check reading that one reports
            // success about a control it never looked at (§5.36). The three hidden bar
            // candidates carry this identifier too, but they are `.accessibilityHidden`,
            // so tests resolve it through `unique(_:)` and fail loudly rather than
            // quietly picking one of four.
            .accessibilityIdentifier("cta_add")
    }

    /// Daylight between this pinned bar and MainShell's hero circle.
    private static let heroClearance: CGFloat = 16

    /// DEBUG-ONLY. Restores the pinned result card, reproducing the 52%-of-content-area
    /// panel this change removes, so `PinnedBarReachabilityUITests` can still be shown
    /// red before it is trusted green. `BAR_SHARE_CAP` is accepted at ANY value as a
    /// legacy alias, because that is the variable the suite already forwards and the
    /// invocation printed in its own doc comment must keep working.
    ///
    /// Not compiled into Release.
    static var forcedPinnedResultForRegressionTest: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["FORCE_PINNED_RESULT"] == "1" || env["BAR_SHARE_CAP"] != nil
        #else
        return false
        #endif
    }

    private func measure(_ key: String) -> some View {
        GeometryReader { g in
            Color.clear.preference(key: BarMetricsKey.self, value: [key: g.size.height])
        }
    }

    /// DEBUG-ONLY. Publishes what the LAYOUT actually produced, so a test asserts the
    /// rendered numbers rather than a proxy the harness inferred.
    ///
    /// The identifier and the `ax=` / `size=` / `cap=` keys are UNCHANGED, and that is
    /// deliberate: three suites read this element (`PinnedBarReachabilityUITests` for
    /// the type size, `LeafOverlapUITests` for the same, `CaptureCurrentState` to prove
    /// the rig is at default before it files a frame under a name claiming default).
    /// Renaming the keys with the gate would have silently broken all three.
    ///
    /// `cap=` now reports the LEGACY `BAR_SHARE_CAP` value, or 0 when it is unset. It no
    /// longer gates anything — see `forcedPinnedResultForRegressionTest` — but
    /// `CaptureCurrentState` asserts the override ARRIVED, and that assertion is still
    /// the right one: it is what stops a frame being filed under a setting the app never
    /// saw.
    ///
    /// `bar=` and `share=` are new, and they are the evidence for the pass condition in
    /// `SPEC-RESULT-SHEET-AND-SYRINGE §8`: the bar's rendered height, and that height as
    /// a share of the content area. Both come from the renderer.
    ///
    /// Zero-sized and out of the accessibility tree's way; not compiled into Release.
    @ViewBuilder
    private var gateProbe: some View {
        #if DEBUG
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityElement()
            .accessibilityIdentifier("bar_gate")
            .accessibilityLabel(gateProbeLabel)
        #endif
    }

    #if DEBUG
    /// Built here rather than inline in the modifier: as one expression the type
    /// checker gave up on it outright.
    private var gateProbeLabel: String {
        var parts: [String] = []
        parts.append("ax=\(isAccessibilitySize)")
        // The CATEGORY, not just the accessibility flag. `ax=false` is true at `large`,
        // `xLarge` and `xxxLarge` alike, so nothing in the harness could tell the default
        // size from a merely-non-accessibility one — and every frame in the default
        // capture sweep is filed under a name that CLAIMS default. A run whose filenames
        // assert a rig setting it cannot observe is the §5.24 shape: it reports success
        // either way.
        parts.append("size=\(typeSize)")
        let legacyCap = ProcessInfo.processInfo.environment["BAR_SHARE_CAP"]
            .flatMap(Double.init) ?? 0
        parts.append(String(format: "cap=%.4f", legacyCap))
        parts.append("forcedPinned=\(Self.forcedPinnedResultForRegressionTest)")
        let area = contentAreaAtRest
        let bar = metrics[BarMetrics.bar] ?? -1
        parts.append(String(format: "area=%.2f", area))
        parts.append(String(format: "bar=%.2f", bar))
        // -1 rather than a plausible-looking 0: a share computed from an unmeasured bar
        // must not read as "the bar takes none of the screen".
        parts.append(String(format: "share=%.4f", area > 0 && bar > 0 ? bar / area : -1))
        return parts.joined(separator: " ")
    }
    #endif
}

// MARK: - Measured layout plumbing

enum BarMetrics {
    static let contentArea = "contentArea"
    /// The pinned bar's RENDERED height. There is one bar now, so there is one height —
    /// the ladder of hidden candidates that used to be measured here is gone.
    static let bar = "bar"
}

private struct BarMetricsKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    /// `max` rather than last-write: several proxies report during a layout pass and
    /// a transient zero from one that has not been positioned yet must not be able to
    /// unpin the bar for a frame.
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { max($0, $1) }
    }
}

// MARK: - Screen header
//
// H5, and it is `DESIGN-PARITY §9` OPTION (a) rather than H5's own wording.
//
// H5 says the calculator name moves "into the top navigation bar". §9 says it cannot,
// and it says so FROM A DEVICE MEASUREMENT rather than from a source read: a wrapping
// `Text` in `.principal` renders two lines and CLIPS THE THIRD AT BOTH ENDS, with no
// ellipsis and nothing on screen signalling the loss. On a dosing app a title that
// silently loses characters is worse than one that truncates visibly, because
// truncation at least announces itself. The measurement outranks the wording.
//
// So the header is in the content area, where it can wrap freely to any line count.
//
// What §9 requires, and what each line below is for:
//   1. the syringe mark beside the title, SIZED TO IT — it inherits the title's font
//      rather than carrying a frozen point size, which is what stops the Tools-at-AX5
//      failure (icons staying small while the text went huge) arriving here;
//   2. the wordmark's typeface and weight, in `tealTextStrong` #075E56 at 7.65:1 —
//      `Theme.Typeface.greeting` is title2/heavy, the same family as `BrandWordmark`
//      and, unlike `BrandWordmark`'s frozen 17pt, it scales;
//   3. mark + title centred as ONE unit at any line count;
//   4. **A LONG TITLE WRAPS. NO `lineLimit`, EVER** — CLAUDE.md names a screen title
//      as one of the two things that may never carry one;
//   5. the back control is untouched, because it stays in the navigation bar.
//
// One accessibility element with `.isHeader`; the mark is decorative and is not
// announced separately.
private struct ScreenHeader: View {
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
            Image(systemName: "syringe.fill")
                .foregroundStyle(Theme.accent)
                // ITS OWN NAME, BECAUSE `syringe` WAS ALREADY TAKEN — §5.38 in its
                // plainest form. `MainShell`'s raised hero glyph answers to
                // `app.images["syringe"]` and `CaptureCurrentState` resolves the hero
                // through exactly that name; this mark arriving on every calculator
                // made that query ambiguous, and an ambiguous element fails at
                // RESOLUTION, before any assertion runs. `testCaptureFullDefaultSweep`
                // died after one calculator and 22 frames were not taken.
                //
                // THE IDENTIFIER ALONE IS NOT ENOUGH, and this is the part worth
                // reading: XCUITest's `[]` subscript matches an element's LABEL as well
                // as its identifier — which is how the hero, which carries no
                // identifier anywhere in `MainShell`, is found by that name at all. So
                // the label goes too. Empty rather than descriptive: this glyph is
                // decoration beside a title that says the same thing, and the container
                // below announces the pair as one `.isHeader` element.
                //
                // `accessibilityHidden` is KEPT and is not what fixes this.
                // `MainShell.heroButton` records the reason from two measurements: the
                // flag is applied to that Image directly and the element is in the tree
                // anyway, byte-identical frame both times. A decorative duplicate has to
                // be NAMED, not hidden, because hiding it here is not observed to work.
                .accessibilityIdentifier("mark_screen_title")
                .accessibilityLabel(Text(verbatim: ""))
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Theme.tealTextStrong)
                .multilineTextAlignment(.center)
                // The whole point of option (a): the title takes the height it needs
                // instead of losing characters. Vertical only — a horizontal fixedSize
                // would refuse to wrap and overflow the screen instead.
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.Typeface.greeting)
        .tracking(Theme.Typeface.greetingTracking)
        // Sizes to the content and centres it; at a size where the title wraps, the
        // pair fills the width and `multilineTextAlignment` keeps the lines centred.
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("screen_title")
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Result card

private struct ResultCard: View {
    let result: CalculatorResult
    var barrelMl: Double?
    /// Identifier namespace. `result_` for the card in the scroll, `sheet_result_` for
    /// the sheet, `pinned_result_` for the DEBUG defect reproduction.
    ///
    /// THIS IS NOT COSMETIC. Two surfaces emitting `result_<label>` is an AMBIGUOUS
    /// XCUIElement, and an ambiguous element fails at RESOLUTION — before any assertion
    /// runs, so the failure reads as a broken test rather than as the two copies of a
    /// dose it actually is. Measured once already: `result_Weekly total` resolved to two
    /// elements, y=641 and y=896, and killed `testQuickChip_fieldAndResultBothFollow`.
    ///
    /// The rule the gate's removal restores: EXACTLY ONE ELEMENT PER LABEL PER SURFACE,
    /// and `result_` is the surface on screen at rest. The `detail_result_` /
    /// surface-following scheme is gone with the pinned copy that forced it — there is
    /// no longer a second card competing for the bare name.
    var idPrefix: String = "result_"

    private func identifier(for label: String) -> String { idPrefix + label }

    private var overCapacity: Bool {
        guard let barrelMl, let draw = result.drawMl, result.isValid else { return false }
        // Tolerate float noise; a draw exactly equal to the barrel still fits.
        return draw > barrelMl + 0.0005
    }

    /// Two different situations, deliberately worded differently. A draw slightly
    /// over the barrel is a normal split — 0.6 mL into a 0.5 mL barrel is two
    /// injections and a legitimate workflow. A draw many times the barrel is almost
    /// always a mis-set field, and reading it in the same neutral tone as the benign
    /// case is how a wrong number survives. The threshold is draws-required, not a
    /// colour or an icon change: both cases carry the same warning triangle, so the
    /// distinction is in the words, never in the styling alone.
    private var capacityNote: String? {
        guard overCapacity, let barrelMl, let draw = result.drawMl else { return nil }
        let draws = Int(ceil(draw / barrelMl))
        if draws >= 4 {
            return String(format: "Draw of %.3f mL needs %d fills of a %@ barrel. Check the dose and vial strength — that is usually a typo, not a split.",
                          draw, draws, barrelLabel(barrelMl))
        }
        return String(format: "Draw of %.3f mL exceeds the %@ barrel — split it across %d injections or choose a larger barrel.",
                      draw, barrelLabel(barrelMl), draws)
    }

    private func barrelLabel(_ ml: Double) -> String {
        ml == ml.rounded() ? "\(Int(ml)) mL" : "\(ml) mL"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if result.isValid {
                // EVERY row, unconditionally. There is no longer a rung deciding which
                // of them the user is allowed to see: the panel that made that decision
                // necessary — by owning 52.40% of the content area — is gone, and the
                // card now sits in the scroll where vertical space is cheap.
                //
                // The weekly total is the CROSS-CHECK, not a derived nicety: the user
                // typed "400 mg/week" and this is how they confirm the app understood
                // them. It was surrendered above the old cap. It is not surrendered now.
                ForEach(result.rows) { row in
                    if row.emphasis {
                        PrimaryResultRow(label: row.label, value: row.value,
                                         identifier: identifier(for: row.label))
                    } else {
                        SecondaryResultRow(label: row.label, value: row.value,
                                           identifier: identifier(for: row.label))
                    }
                }
                // Was an orphaned grey string with no label — at AX sizes it read
                // as a stray word ("Ideal") floating under the numbers. It is a
                // verdict on the draw volume, so it gets a label like every other row.
                if let line = result.scheduleLine {
                    SecondaryResultRow(label: "Volume", value: line,
                                       identifier: identifier(for: "Volume"))
                }
                // The engine's own advisories (T-45), ABOVE the barrel note and in
                // the web's order. Two different kinds of statement, deliberately
                // styled apart: these are about the DOSE — is it above the compound's
                // typical weekly maximum, is the draw too small to measure — while
                // the capacity note below is about whether the number fits the
                // hardware. Same amber-vs-red distinction the web draws with its
                // orange `InfoBox`.
                // INDEXED, not named after the sentence and not sharing one name.
                // Two elements answering to one identifier is an AMBIGUOUS query and
                // it fails at RESOLUTION, before any assertion runs — the failure this
                // file already paid for once with `result_Weekly total`. Both notes
                // cannot currently fire at once (that needs conc > 100 × dose, and
                // conc clamps at 60), but a test must not be resting on that.
                ForEach(Array(result.notes.enumerated()), id: \.offset) { i, note in
                    AdvisoryNote(text: note, identifier: "\(idPrefix)note_\(i)")
                }
                if let note = capacityNote {
                    CapacityWarning(text: note)
                }
            } else {
                Text("Enter values to calculate")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Theme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Result sheet
//
// `SPEC-RESULT-SHEET-AND-SYRINGE §2`. The reading surface the pinned bar now opens.
//
// A `.sheet` WITH DETENTS, not a `.fullScreenCover`, and the spec is explicit about
// why: the user is comparing the sheet against the inputs behind it, so the inputs must
// not vanish.
//
// WHAT THE SPEC ASKED FOR AND WHAT THIS RENDERS — stated because they are not identical
// and the difference is an architecture finding, not an omission.
//
// §2 lists a fixed triple: `Amount to draw` (units, largest), `Volume` (mL, 3 dp),
// `Dose` (mg, 1 dp). That is the shape of ONE calculator's result. `CalculatorResult`
// carries `rows` plus a structured `drawMl` and nothing else — there is no `units` and
// no `doseMg` on it — and fifteen calculators feed it: BMI produces no volume at all,
// Reconstitution produces `Add bac water`, Free T Index produces a ratio. Hard-coding
// three named slots here would mean either a per-calculator branch on this screen (the
// thing this pass exists to remove) or three labels rendering empty on the calculators
// that do not produce them.
//
// So the sheet renders the result AS THE ENGINE PRODUCES IT, in the spec's order of
// emphasis: the lead emphasised figure largest, the remaining rows under it, then the
// barrel line and the capacity warning. On TRT that yields exactly §2's list, from the
// engine's own labels, because the engine already produces those three rows.
//
// The structured route — adding `units` and `doseMg` to `CalculatorResult` so the sheet
// can name them — is the right fix and it belongs in the engine, not here. Reported.
private struct ResultSheet: View {
    let result: CalculatorResult
    var barrelMl: Double?
    let title: String

    @Environment(\.dismiss) private var dismiss
    /// VoiceOver lands on the dose figure when the sheet opens (§6), and returns to the
    /// invoking control when it closes — which the system does for a `.sheet`.
    @AccessibilityFocusState private var focusOnLead: Bool

    /// `Insulin U-100` or `Standard luer`, from `syringeMl <= 1.0` (§2.5).
    ///
    /// DERIVED FROM THE SELECTED BARREL, never hardcoded. That is the whole of the
    /// answer `RESULT-PANEL-SPEC §4` demanded before a syringe could be drawn, and T27
    /// is closed by construction only for as long as this stays derived.
    private var barrelLine: String? {
        guard let barrelMl else { return nil }
        return barrelMl <= 1.0 ? "Insulin U-100" : "Standard luer"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    if result.isValid {
                        // The card carries its own identifier namespace, so the sheet
                        // and the in-scroll copy never answer to the same name.
                        ResultCard(result: result, barrelMl: barrelMl,
                                   idPrefix: "sheet_result_")
                            .accessibilityFocused($focusOnLead)

                        if let barrelLine {
                            SecondaryResultRow(label: "Syringe", value: barrelLine,
                                               identifier: "sheet_result_Syringe")
                                .padding(.horizontal, Theme.Spacing.xs)
                        }
                    } else {
                        Text("Enter values to calculate")
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    // WHERE THE SYRINGE GOES. §3–§5 — the drawn barrel, the fill front,
                    // the over-capacity colouring and the zoom — mount here, against
                    // `barrelMl` and `result.drawMl`, which are the only two inputs that
                    // geometry needs and both are already in scope. Not built in this
                    // pass: §8 sequences it after the bar and the numbers because it
                    // passes on photographs at four barrels × two text sizes.
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("sheet_done")
                }
            }
        }
        // `.medium` first so the inputs behind stay visible — the reason this is a sheet
        // and not a cover. `.large` because at AX5 the figures reflow to several times
        // the height and a fixed medium would clip them.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { focusOnLead = true }
    }
}

/// A dosing advisory from the engine — the web's orange `InfoBox` (T-45).
///
/// AMBER, NOT RED, and the two are different statements. `CapacityWarning` below is
/// red because the number does not fit the syringe in front of the user: it cannot be
/// drawn as shown. This one carries a dose that is entirely drawable and entirely
/// possibly correct — *"Exceeds typical weekly maximum of 2.4 mg — verify with your
/// prescriber"* is addressed to someone who may well have been prescribed it. Painting
/// that red would either stop a legitimate protocol or, far worse, teach the user that
/// red on this screen is usually nothing.
///
/// Same construction as `CapacityWarning` otherwise: icon + text + filled shape, so it
/// survives greyscale and every form of colour vision deficiency, and it is one
/// combined accessibility element so VoiceOver reads the sentence rather than the icon.
/// `Theme.warning` is #B45309 — the web's #F97316 taken to a text-legal contrast
/// (5.9:1 on the card) rather than shipped at the web's own ratio.
private struct AdvisoryNote: View {
    let text: String
    let identifier: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.warning)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.warning)
                // NEVER truncates. The sentence names a number (`2.4 mg`) and then
                // says what to do about it; a note clipped at "Exceeds typical weekly
                // maxim…" has lost the only actionable half.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.warning.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning. \(text)")
        .accessibilityIdentifier(identifier)
    }
}

/// Over-capacity notice. Icon + text + shape, so it survives greyscale and every
/// form of colour vision deficiency; the red is reinforcement, not the signal.
private struct CapacityWarning: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.danger)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.danger.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Warning. \(text)")
    }
}

// MARK: - Result rows
//
// AUDIT FINDING F1 (highest severity): the old rows were
// `HStack { Text(label); Spacer(); Text(value) }`. A single-line HStack with a
// Spacer between two Texts has no fallback axis, so at accessibility text sizes
// SwiftUI truncated BOTH children — "0.250 mL" rendered as "0.25…", losing the
// unit. In a dosing calculator 0.25 with no unit has two plausible readings
// (0.25 mL vs 25 units on a U-100 barrel) and nothing on screen disambiguates.
//
// The rule these two views enforce: a value and its unit are one indivisible
// string, and NOTHING here may carry `.lineLimit(1)`. The primary row stacks
// label-above-value unconditionally, so it cannot truncate at any type size.
// The secondary rows try side-by-side first and fall back to stacked via
// `ViewThatFits` when the pair no longer fits on one line.

private struct PrimaryResultRow: View {
    let label: String
    let value: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Typeface.eyebrow)
                .foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .accessibilityIdentifier(identifier)
                // T19: the renderer publishes whether this truncated, rather than the
                // harness inferring it from a ratio. `identifier` already names the
                // surface, so the probe inherits that naming for free.
                .truncationProbe(identifier)
                .font(Theme.Typeface.display)
                .tracking(Theme.Typeface.displayTracking)
                .monospacedDigit()
                // #075E56 at 7.65:1, not #0FBCAD at 2.34:1. This is the number
                // the user acts on; it was previously the lowest-contrast text
                // on the screen while the secondary rows beside it sat near 20:1.
                .foregroundStyle(Theme.tealTextStrong)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SecondaryResultRow: View {
    let label: String
    let value: String
    let identifier: String

    /// ONE definition of the value, used by both `ViewThatFits` branches.
    ///
    /// The identifier used to sit on the side-by-side branch only, so it vanished at
    /// exactly the sizes the stacked branch exists for. Hoisting it onto the
    /// `ViewThatFits` is worse, not better: SwiftUI propagates accessibility
    /// modifiers from a non-element container down to every descendant, so the LABEL
    /// text would answer to `result_<label>` as well as the value, and an assertion
    /// on `.label` would be a coin toss that passes most of the time. A shared
    /// subview is the only form that yields exactly one element and cannot drift.
    private var valueText: some View {
        Text(value)
            .font(Theme.Typeface.resultLabel.weight(.semibold))
            .accessibilityIdentifier(identifier)
            .truncationProbe(identifier)
            .monospacedDigit()
            .foregroundStyle(Theme.ink)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(label).font(Theme.Typeface.resultLabel).foregroundStyle(Theme.secondaryLabel)
                Spacer(minLength: Theme.Spacing.sm)
                valueText
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(Theme.Typeface.resultLabel).foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                valueText
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Field row

private struct FieldRow: View {
    let field: CalculatorInput
    @ObservedObject var vm: CalculatorViewModel
    var focusedKey: FocusState<String?>.Binding

    private var fieldUnit: String? {
        if case let .number(unit, _, _, _) = field.kind { return unit }
        return nil
    }

    /// Numeric fields get the web's ROW treatment — label, value and ruler inside
    /// one flat grey group. Everything else keeps its label above the control,
    /// which is what the web does too (`FieldLabel` above `ChipRow`/`ModeTab`).
    private var isNumeric: Bool {
        if case .number = field.kind { return true }
        return false
    }

    /// The mode switcher carries NO label on the real page. `ModeTab.tsx`'s preview
    /// wraps it in a `FieldLabel`, but the TRT call site (`app.js:8396`) passes none
    /// and the reference frame shows it sitting directly under the breadcrumb. The
    /// preview is the component's demo, not the page.
    private var isMode: Bool {
        if case .modePicker = field.kind { return true }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if isNumeric {
                numericRow
            } else {
                // T-01a #10 — SMALL CAPS SECTION HEADERS, so grouped controls read
                // as a group. iOS used sentence-case field labels throughout and
                // nothing grouped: `Syringe barrel` looked like a peer of
                // `Weekly dose` rather than a heading over a set of choices.
                if !isMode {
                    CalcSectionHeader(title: field.label)
                }
                content
            }

            // Hidden while THIS field is being edited, because the keyboard toolbar
            // is showing the same five values at that moment. Two identical control
            // rows on one screen is the same smell as two copies of a dose readout —
            // and this is the copy that is occluded by the pinned result bar anyway,
            // so what is being removed is a row the user cannot reach.
            if !field.quick.isEmpty && focusedKey.wrappedValue != field.key {
                QuickValueRow(key: field.key,
                              values: field.quick,
                              unit: fieldUnit,
                              selection: vm.numberBinding(field.key))
            }

            if let help = field.help {
                Text(help).font(.caption2).foregroundStyle(Theme.secondaryLabel)
            }
        }
    }

    // MARK: The web's numeric row  (T-01a #7, #8, #9)
    //
    // `[ LABEL ][ value ][ ruler ]`, all inside one flat #F1F1F4 group. Three of the
    // twelve differences are this one row:
    //   #8 label placement — web puts it LEFT of the value on the same line; iOS
    //      stacked it above, so the row was two lines tall and read as two things.
    //   #9 value emphasis — the value sits in a navy-outlined recessed well, so the
    //      number is the focus of the row rather than ordinary text in a box.
    //   #7 the ruler — see `TickDrum`.
    //
    // `ViewThatFits` chooses the axis, and it chooses by LAYOUT rather than by a
    // Dynamic Type category — the same rule the rest of this file lives by, for the
    // same reason: `if isAccessibilitySize` is the exact guess the retired pinning
    // gate was retired for. The ruler carries a `minWidth` so the fit test has a real
    // number to compare; a bare `GeometryReader` reports no ideal width and the test
    // would always pick the row.
    private var numericRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Theme.Spacing.sm) {
                rowLabel
                content
                drumStrip
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    rowLabel
                    Spacer(minLength: Theme.Spacing.sm)
                    content
                }
                drumStrip
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.fieldRowFill)
        )
    }

    private var rowLabel: some View {
        Text(field.label)
            .textCase(.uppercase)
            .font(Theme.Typeface.eyebrow)
            .tracking(0.5)
            .foregroundStyle(Theme.secondaryLabel)
            // Wraps rather than truncating. A label is not a value+unit pair, but
            // `Weekly dose` shearing to `Weekly d…` beside a number is still a row
            // whose number has no name.
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var drumStrip: some View {
        if !field.drum.isEmpty {
            TickDrum(values: field.drum,
                     selection: vm.numberBinding(field.key),
                     key: field.key)
                // The fit test's input. Below this the ruler stops being a ruler —
                // four gradations do not show you where you are on a range.
                .frame(minWidth: 110)
        }
    }

    /// A full-width 44pt row that toggles, with the system switch drawn inside it.
    private func toggleRow(field: CalculatorInput, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(Theme.accent)
                    // The row is the single tap handler; without this the switch
                    // would consume its own taps and the row's gesture would fire
                    // too, toggling twice to a net no-op.
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(field.label)
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var content: some View {
        switch field.kind {
        case let .number(unit, _, range, step):
            NumberField(key: field.key, value: vm.numberBinding(field.key),
                        unit: unit, range: range, step: step, focusedKey: focusedKey)

        case let .picker(options, _):
            // T-16 — THE NUMERIC HALF OF THE PICKER OVERLAP, closed.
            //
            // WHAT WAS HERE: `.pickerStyle(.menu)`, whose selected value DRAWS OUTSIDE
            // ITS OWN CHROME at large text and lands on the label above it. Measured on
            // IB2245752 — `Oxandrolone (Anavar)` occupies {{83.3, 192.7}, {193.0, 183.3}}
            // inside a button of {{15.5, 245.5}, {371.3, 78.3}}, overlapping `Compound`
            // by 148.6 x 49.3pt. Ten `.picker` fields across seven calculators render
            // through this one case, plus the plotter's own two menus — the "12 picker
            // fields across 8 calculators" the finding was recorded against.
            //
            // WHAT WAS RULED OUT, kept because it is the expensive half of the work:
            // adding `.fixedSize(horizontal: false, vertical: true)` to the menu picker
            // — the obvious "let it grow" fix — changed the geometry by NOTHING.
            // Re-measured after the change: the same 193.0 x 183.3 text in the same
            // 371.3 x 78.3 button, identical to the byte. `.pickerStyle(.menu)` does not
            // let its label's multiline height reach the control's frame, so the fix has
            // to REPLACE THE STYLE rather than modify it. Do not retry the modifier.
            //
            // WHAT REPLACES IT: the same `Combobox` the ester field already uses, in its
            // `Double`-carrying wrapper. The face is a button we lay out ourselves, so
            // the value wraps inside the chrome and the chrome grows to hold it; and the
            // list arrives with the web's search, which the menu never had.
            ValueCombobox(label: field.label,
                          options: options,
                          selection: vm.numberBinding(field.key),
                          key: field.key)

        case let .segmented(options, _):
            SegmentedRow(key: field.key, options: options,
                         selection: vm.numberBinding(field.key))

        case let .modePicker(options, _):
            // T-01a #1 — the control iOS never had.
            ModeTab(modes: options.map { .init(label: $0.label, value: $0.value) },
                    selection: vm.stringBinding(field.key))

        case let .stringPicker(options, _):
            // T-01a #2 — a SEARCHABLE combobox, replacing `.pickerStyle(.menu)`.
            //
            // Applied to every `stringPicker` in the app, not only TRT's ester, and
            // that is deliberate rather than scope creep: the menu picker carried a
            // MEASURED open defect — its selected value draws outside its own chrome
            // at large text and lands on the label above it, `Oxandrolone (Anavar)`
            // overlapping `Compound` by 148.6 x 49.3pt on IB2245752 — and the note
            // recording it says the fix is "replacing the style with a `Menu` whose
            // label we lay out ourselves". This is that, arriving with the search the
            // web has. The remaining menu pickers (`.picker`, numeric) are untouched
            // and still carry the defect; they are listed in TASKS.md.
            CompoundCombobox(label: field.label,
                             options: options,
                             selection: vm.stringBinding(field.key),
                             key: field.key)

        case .toggle:
            // The switch alone was the tap target: ~51x31pt, under the 44pt floor,
            // on a control that changes which units a dose is calculated in. Proven
            // behaviourally — tapping the row at x=250pt did nothing while tapping
            // the switch at x=30pt flipped it. `maxWidth: .infinity` widened the
            // LAYOUT frame without extending the hit area.
            //
            // The system switch is kept and made non-interactive; the row owns the
            // tap. Replacing UISwitch to win a consistency argument would be
            // off-platform and would lose its own accessibility behaviour —
            // DESIGN-PARITY §6 keeps native controls native.
            toggleRow(field: field, isOn: vm.boolBinding(field.key))

        case let .stepperDays(_, range):
            Stepper(value: vm.numberBinding(field.key), in: range, step: 1) {
                Text("\(Int(vm.values.number(field.key))) days")
            }
        }
    }
}

// MARK: - Quick values

/// One-tap values under a numeric field. A dose is picked from a handful of round
/// numbers far more often than it is typed, and typing still works — this is a
/// shortcut, never the only way in. Selection is shown by fill AND weight, not by
/// colour alone.
private struct QuickValueRow: View {
    let key: String
    let values: [Double]
    let unit: String?
    @Binding var selection: Double
    /// `quick_` for the row under the field, `kb_quick_` for the copy in the
    /// keyboard toolbar. Both are on screen while a field is being edited, and one
    /// identifier answering to two elements is an ambiguous query — it fails at
    /// resolution, before any assertion runs.
    var idPrefix: String = "quick_"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(values, id: \.self) { value in
                    let isOn = abs(selection - value) < 0.0001
                    Button { selection = value } label: {
                        Text(Self.format(value))
                            .font(isOn ? Theme.Typeface.cardMeta.weight(.bold)
                                       : Theme.Typeface.cardMeta)
                            .foregroundStyle(isOn ? .white : Theme.tealTextStrong)
                            .padding(.horizontal, Theme.Spacing.md)
                            .frame(minWidth: 60, minHeight: Theme.minTarget)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control)
                                    .fill(isOn ? Theme.navy : Theme.accentSoft)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("\(idPrefix)\(key)_\(Self.format(value))")
                    .accessibilityLabel(unit.map { "\(Self.format(value)) \($0)" } ?? Self.format(value))
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.vertical, 2)
        }
        // The row scrolls, so it never truncates a value at large text sizes.
        .scrollDisabled(false)
    }

    static func format(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%g", d)
    }
}

// MARK: - Segmented row

/// Always-visible options instead of a menu — one tap rather than open-then-pick.
/// Used for the syringe barrel, where there are four choices and the user changes
/// them while holding the syringe.
///
/// ELEVEN CALCULATORS RENDER THROUGH THIS ONE VIEW — trt, eod, microdose, hcg, peptide,
/// semaglutide, tirzepatide, retatrutide, bpc157, bpc157blend, steroid — so what is
/// fixed here is fixed on all of them and what is broken here was broken on all of them.
///
/// WHAT WAS BROKEN: `.lineLimit(2)`, on `CalculatorCatalog.barrelOptions` — which are
/// `0.3 mL (30u)`, `0.5 mL (50u)`, `1 mL (100u)`, `3 mL (IM)`. **Those are value+unit
/// pairs.** CLAUDE.md bans `lineLimit` on a value+unit pair outright, and this file
/// restates the ban twice in comments a few hundred lines away — `NOTHING here may carry
/// .lineLimit(1)` above the result rows, and `F1 banned lineLimit on a value+unit pair`
/// above `NumberField`. The ban was being violated by the shared control the comments
/// sit beside. `0.3 mL (…` and `0.5 mL (…` are the same string to a reader choosing a
/// barrel, and picking the wrong barrel is a dosing error.
///
/// WHAT REPLACES IT: a fallback AXIS, not a smaller cap. `ViewThatFits` takes the row
/// while four labels fit side by side on ONE line each, and stacks them into a column
/// when they do not — the same pattern `SecondaryResultRow` uses, for the same reason.
/// The row branch is measurable because `.frame(maxWidth: .infinity)` reports its
/// CHILD's ideal width when proposed `nil`, so the fit test compares four real strings
/// while the pills still expand to equal widths.
///
/// AND THE FIT TEST WAS ASKING THE WRONG QUESTION — the correction, measured, is in
/// `MinimumWidthAsIdeal` below this type. "Four real strings" was true and still not
/// enough: it compared them UNWRAPPED, so the control took the column branch at
/// default size on all eleven calculators and put ~116pt of stacked pills above the
/// result card. Read that comment before changing anything here; it carries the
/// numbers.
///
/// WHAT IS DELIBERATELY LEFT: `.minimumScaleFactor(0.8)`, which caps Dynamic Type growth
/// at 80% on this control. It is a real defect of the same family and it is **H1's
/// territory, and H1 is deferred by the owner** — so it stays, and it stays annotated,
/// rather than being read by the next person as an oversight nobody noticed. Removing it
/// in this pass would also change the fit test's inputs on eleven screens in a pass whose
/// evidence is a single run.
private struct SegmentedRow: View {
    /// The field key, so each option can be addressed individually. Without it the
    /// barrel buttons carry NO identifier and no reachability sweep can name them —
    /// which is why "the four buried barrel buttons" was a finding read off a
    /// screenshot rather than a measurement.
    ///
    /// `control_` deliberately, matching the menu pickers: that is the prefix
    /// `PinnedBarReachabilityUITests.inputControls()` already collects, so the barrel
    /// enters the existing straddle-and-reachability sweep with no change to that
    /// suite. The per-option suffix is what keeps this safe — BOARD's objection was to
    /// an identifier on the CONTAINER propagating to every button inside it, which is
    /// the ambiguity that cost a session; one identifier per button has the opposite
    /// property.
    let key: String
    let options: [CalculatorInput.PickerOption]
    @Binding var selection: Double

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(options) { opt in button(opt) }
            }
            VStack(spacing: Theme.Spacing.xs) {
                ForEach(options) { opt in button(opt) }
            }
        }
    }

    private func button(_ opt: CalculatorInput.PickerOption) -> some View {
        let isOn = abs(selection - opt.value) < 0.0001
        let font = isOn ? Theme.Typeface.cardMeta.weight(.bold) : Theme.Typeface.cardMeta
        return Button { selection = opt.value } label: {
            // THE FIT TEST'S INPUT — the whole of the fix, and see the note below the
            // type. The first child is the label as it really renders; the second is
            // the hidden probe whose width the enclosing `ViewThatFits` decides on.
            FitOnWrappedWidth {
                Text(opt.label)
                    .font(font)
                    .foregroundStyle(isOn ? .white : Theme.tealTextStrong)
                    // NO `lineLimit`. The pair wraps rather than losing its unit, and
                    // the column branch above is what it wraps INTO when a row cannot
                    // hold it.
                    .multilineTextAlignment(.center)
                    // H1 territory, deferred. See the type comment.
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                WidestWordProbe(text: opt.label, font: font)
            }
                .padding(.horizontal, Theme.Spacing.xs)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(isOn ? Theme.navy : Theme.accentSoft)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("control_\(key)_\(opt.label)")
        .accessibilityLabel(opt.label)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// ─── The fit test, made to ask the right question ────────────────────────────
//
// WHAT WAS WRONG, measured rather than reasoned. At default text size, on
// Retatrutide / Semaglutide / Tirzepatide, `SegmentedRow` rendered FOUR stacked
// 44pt rows 4pt apart — `blockHeight=188.0`, `distinctTops=4`, exactly
// `4 × Theme.minTarget + 3 × Spacing.xs` — against ~72pt for the single row of
// pills the same control drew before `69a674a`. ~116pt of form, on the eleven
// calculators listed above, immediately above the result card, and the visible
// consequence was `result_Draw` — the dose VOLUME, the number the user acts on —
// sitting at y 651.67…692.33 against a plate top of 671.0. Sheared through its
// own glyphs, no ellipsis, at default size, in a dosing app.
//
// WHY IT CHOSE THE COLUMN. `ViewThatFits(in: .horizontal)` picks the first
// candidate whose IDEAL width fits the proposal. A `Text`'s ideal width is its
// UNWRAPPED, single-line width — `0.3 mL (30u)` all on one line — so the row
// candidate's ideal was the sum of four full-length strings and never fit. But
// the row branch does not render them unwrapped: each pill is a quarter of the
// width and the pair wraps onto two lines inside it, which is how the control
// looked before the `lineLimit` came out. **The fit test was measuring a layout
// that the row branch never produces.**
//
// WHAT THIS FIXES IT WITH. Not a threshold — a threshold nudged until the branch
// flips is tuning a collision, and it un-flips silently the next time a label
// changes. The row candidate reports, as its ideal, the narrowest width at which
// the label still renders the way a row is supposed to render it: WRAPPED AT
// SPACES. That width is the width of the label's widest WORD, and it is measured
// rather than assumed — `WidestWordProbe` lays the words on top of one another in
// a `ZStack` at the real font, and a `ZStack`'s ideal width is the widest of its
// children. `ViewThatFits` then compares like with like.
//
// AND THE FIRST VERSION OF THIS GOT IT WRONG, which is why the paragraph is here
// rather than a tidier one. It reported `sizeThatFits(ProposedViewSize(width: 0))`
// — the content's absolute minimum width — on the reasoning that a `Text` proposed
// nothing gives back its longest unbreakable run. IT DOES NOT. SwiftUI will break
// a word rather than refuse a width, so that "minimum" is far below any width the
// label reads correctly at, and the row branch was then chosen at EVERY size. At
// AX5 the four pills rendered 89.67pt wide and 232.67pt tall with `(100u)` split
// across two lines as `(10` / `0u)` — every glyph present, nothing clipped, and a
// barrel labelled `1 mL (10 0u)` on a dosing screen. It was caught by photographing
// the row rather than by reading the frames, which said only that four pills sat
// side by side. **A fallback branch that never renders at any size is not a
// fallback**, and the fit test was again measuring something the row does not do.
//
// So the branch now flips for a REASON that survives a label change: the row while
// four space-wrapped labels genuinely fit side by side, the column the moment one
// word alone is wider than its quarter of the screen. Measured both ways, which is
// the only reason to believe it — see the sweep in `BATCH.md` batch 3 item 2.
//
// `lineLimit` STAYS OUT, and this is why it can. The reason the column exists at
// all is that a value+unit pair must never lose its unit — `0.3 mL (…` and
// `0.5 mL (…` are the same string to somebody choosing a barrel. Capping the
// lines would make the row fit by shearing the labels, which is the D4 defect
// this control was fixed to remove, traded for the D4 defect it currently causes
// one card lower down. Neither is acceptable, and neither is needed.
//
// `minimumScaleFactor(0.8)` is likewise NOT touched — see `SegmentedRow`'s type
// comment. It is a real defect of the same family, it is H1's, and H1 is deferred
// by the owner. It stays, deliberately. The probe does NOT carry it, and that is
// on purpose: the question the fit test asks is whether the label fits AT ITS OWN
// SIZE, not whether it could be shrunk until it did.

/// Hidden, and its only output is a WIDTH: the width of the widest word in
/// `text`, at `font`, as the renderer measures it.
///
/// A `ZStack` because a `ZStack`'s ideal size is the maximum of its children's —
/// which is exactly "the widest word" and needs no arithmetic, no font metrics and
/// no guess about which word is longest. (`"(100u)"` is wider than `"0.3"` and
/// narrower than `"Reconstitution"`; character counts do not settle it and glyph
/// widths are not ours to hard-code.)
///
/// `accessibilityHidden` as well as `hidden()`, and that is not belt-and-braces:
/// `.hidden()` leaves the element in the accessibility tree (D3), and this copy
/// carries the same barrel strings as the real label, so VoiceOver would meet every
/// option twice — a defect introduced by the thing measuring for defects.
private struct WidestWordProbe: View {
    let text: String
    let font: Font

    var body: some View {
        ZStack {
            ForEach(Array(text.split(separator: " ").enumerated()), id: \.offset) { _, word in
                Text(String(word)).font(font).fixedSize()
            }
        }
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A pass-through `Layout` with exactly one job: change what "ideal width" means
/// for its content, and change NOTHING else.
///
/// Two subviews, in order — the label as it really renders, and the probe. A
/// `Layout` rather than a modifier because only a `Layout` can size itself from one
/// child while laying out another; a `.background` or `.overlay` cannot contribute
/// to its parent's size, which is the entire quantity in question here.
///
/// Every proposal that carries a width is forwarded untouched, so the control sizes
/// and draws in both branches precisely as it did before. The single value that
/// changes is the number `ViewThatFits` reads while it is choosing.
private struct FitOnWrappedWidth: Layout {

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        // A width WAS proposed: real layout, not the fit test. Answer as the content
        // would have answered. Nothing about rendering is changed here.
        guard proposal.width == nil else { return content.sizeThatFits(proposal) }

        // No width proposed — this is the ideal, and the ideal is what `ViewThatFits`
        // compares. Report the width below which the label would start breaking words,
        // and the height the label really takes at that width.
        let probe = subviews.count > 1 ? subviews[1] : content
        let width = probe.sizeThatFits(.unspecified).width
        let height = content.sizeThatFits(
            ProposedViewSize(width: width, height: proposal.height)).height
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        guard let content = subviews.first else { return }
        content.place(at: CGPoint(x: bounds.midX, y: bounds.midY),
                      anchor: .center,
                      proposal: ProposedViewSize(bounds.size))
        // The probe is never drawn and must never claim space. Placed rather than
        // skipped because an unplaced subview is a runtime complaint, not a no-op.
        if subviews.count > 1 {
            subviews[1].place(at: CGPoint(x: bounds.midX, y: bounds.midY),
                              anchor: .center,
                              proposal: ProposedViewSize(width: 0, height: 0))
        }
    }
}

// MARK: - Number field with optional stepper

private struct NumberField: View {
    /// Storage key — also the accessibility identifier, so a UI test can address
    /// this field rather than guessing at an index among several on screen.
    let key: String
    @Binding var value: Double
    let unit: String?
    let range: ClosedRange<Double>?
    let step: Double?

    @State private var text: String = ""

    /// THE FIELD'S EMPTY REPRESENTATION, and it is the whole of batch-2 item 1.
    ///
    /// `value` is a `Double` and a `Double` has no way to say *the user cleared this
    /// field* — `0` is a real number the engine can be handed. So emptying the text
    /// wrote `0` into the binding, the `value` edge below formatted that `0` straight
    /// back into the text, and the control fought its own input: every
    /// backspace-to-empty left a literal `0` for the next keystrokes to append to.
    /// Clearing a weekly dose and typing `137` produced `0137`. MEASURED, not
    /// inferred: `AddFlowToDoseLogUITests` failed
    /// `XCTAssertEqual ("Optional("0137")") is not equal to ("Optional("137")")`.
    /// `Double("0137")` is 137, so this was never a dosing error — it was a leading
    /// zero the user did not type, on every numeric field in the app.
    ///
    /// AN OPTIONAL, NOT A SENTINEL, and the binding is the reason. A sentinel — `-1`,
    /// `.nan`, `-.greatestFiniteMagnitude` — would have to travel down
    /// `vm.numberBinding(key)` into `CalculatorViewModel` and from there into the
    /// engine, where every one of them is a number some calculator will divide by,
    /// clamp into range or write into `config`. `mgWeek`'s own range starts at 0, so
    /// there is no spare value in the domain to spend either.
    ///
    /// This optional NEVER LEAVES THIS VIEW. The binding still carries `0` while the
    /// field is empty, which is exactly what the engine has always been given for an
    /// empty field and is what keeps `result.isValid` behaving as it did; `nil` here
    /// is only what stops the value edge writing that `0` back into the text. The
    /// text↔value invariant is unchanged in kind — it is still enforced on BOTH edges,
    /// which is what its comment below says it has to be after two historical
    /// breaches — and `""` displays no number at all, so it cannot display a number
    /// the engine did not use.
    @State private var entry: Double?

    /// Shared with every other field on the screen so the keyboard toolbar knows
    /// which field's quick values to show. `focused` below is the local reading.
    var focusedKey: FocusState<String?>.Binding

    private var focused: Bool { focusedKey.wrappedValue == key }

    @Environment(\.dynamicTypeSize) private var typeSize
    private var isAccessibilitySize: Bool { typeSize >= .accessibility1 }

    // AUDIT FINDING, 2026-08-02, and it is finding F1 again on a different control.
    //
    // The row is `[ value ][ unit ][ − ][ + ]` on one line. `mg/week` carries
    // `.fixedSize()` — correct, a unit must never truncate — and the steppers are
    // 44pt each. At AX5 the unit alone took most of the width, so the VALUE was what
    // got squeezed, and the weekly dose rendered as `1…`. In a dosing calculator a
    // field showing `1…` could be 100, 150 or 1000 mg/week and nothing on screen
    // disambiguates it. F1 banned `lineLimit` on a value+unit pair; this reached the
    // same place through layout instead, which is why the ban was necessary but not
    // sufficient.
    //
    // Above AX1 the row reflows: the field takes the full width on its own line, and
    // the unit and steppers move underneath. Nothing truncates because nothing has
    // to share a line with something `.fixedSize()`.
    var body: some View {
        Group {
            if isAccessibilitySize && !Self.forcedInlineForRegressionTest { stacked } else { inline }
        }
        .onTapGesture { focusedKey.wrappedValue = key }
    }

    /// T-01a #9 — THE VALUE WELL. The web wraps the number in a heavy navy-outlined
    /// box so the value is the focus of the row; iOS rendered it as ordinary text in
    /// a bordered container that looked like every other container on the screen.
    ///
    /// `fieldChrome` is deliberately NOT used here and this is the one place in the
    /// app that departs from it. `fieldChrome` is a WHITE fill with a #8E8E93
    /// hairline — correct for an input sitting on the page, wrong for one sitting
    /// inside a grey row, where white-on-grey reads as raised and the web's well is
    /// recessed (#E6E6E9 INSIDE #F1F1F4 — measured, the well is darker than the row
    /// it sits in). The border is #243C73 at 2pt, which is the "heavy navy outline"
    /// of #9 and also clears WCAG 1.4.11 by a wide margin: 12.0:1 against the row.
    ///
    /// The focus ring still wins over it, so the active field stays unambiguous.
    private var valueWell: some View {
        field
            .padding(.horizontal, Theme.Spacing.sm)
            // Room for four digits before the ruler starts stealing width — the
            // reconstitution target concentration holds 1000, so four-digit values
            // are ordinary on this form, not an edge case.
            .frame(minWidth: 62)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.valueWell)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .stroke(focused ? Theme.tealTextStrong : Theme.valueWellBorder,
                            lineWidth: 2)
            )
    }

    @ViewBuilder
    private var unitText: some View {
        if let unit {
            Text(unit)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.secondaryLabel)
                // Paired with `field_<key>` so a test can compare the two
                // geometrically. See DynamicTypeTruncationUITests — the value cell
                // must never be narrower than its own unit.
                .accessibilityIdentifier("unit_\(key)")
        }
    }


    /// DEBUG-ONLY regression hook, and it exists so one specific test can be SHOWN
    /// to fail rather than trusted because it was red once.
    ///
    /// Setting `FORCE_INLINE_FIELD=1` restores the pre-2026-08-02 single-line layout,
    /// which at AX5 renders the weekly dose as `1…`. `DynamicTypeTruncationUITests`
    /// asserts a value cell is never narrower than its own unit; with this flag set,
    /// that assertion goes red on the real defect. Without a way to reproduce the
    /// bug, a test that has never failed has not been shown to work — and this
    /// harness has already reported TEST SUCCEEDED while executing nothing.
    ///
    /// Not compiled into Release.
    private static var forcedInlineForRegressionTest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["FORCE_INLINE_FIELD"] == "1"
        #else
        false
        #endif
    }

    /// Above AX1 the unit drops below the value instead of sharing its line — the
    /// F1 reflow, unchanged in kind. What has gone is the `−`/`+` pair that used to
    /// sit on this line and squeeze the value; see `TickDrum` for what replaced it.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            valueWell
            unitText
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var inline: some View {
        HStack(spacing: Theme.Spacing.sm) {
            valueWell
            unitText
                // A unit must never truncate. `0.25` with no `mL` has two plausible
                // readings on a U-100 barrel and nothing on screen disambiguates.
                .fixedSize()
        }
    }

    private var field: some View {
        Group {
            TextField("0", text: $text)
                .accessibilityIdentifier("field_\(key)")
                // T19 — and this is the probe that closes T4b's DOCUMENTED blind spot.
                // The shipped sweep asserts a RATIO (a value cell is never narrower than
                // its own unit), which is blind to a long value beside a short unit:
                // `1000` truncated to `10…` next to `mg` keeps the ratio and passes.
                // Reconstitution.targetConc holds 1000 in a 49.7pt cell, so four-digit
                // doses are ordinary here.
                //
                // CAVEAT, stated because a green run must not be over-read: the ideal
                // width is measured from a Text carrying the same string and the same
                // font, while the rendered width is the TextField's whole frame — which
                // includes UIKit's internal insets. So this probe is CONSERVATIVE: it
                // fires when the string needs more than the entire cell, and a value
                // clipped by only the inset can still slip through. It is strictly
                // better than the ratio and it is not exact.
                .truncationProbe("field_\(key)")
                .keyboardType(.decimalPad)
                .focused(focusedKey, equals: key)
                // Was `.system(size: 17, weight: .semibold)` — a FROZEN size at a
                // call site, which the Theme re-baseline could not reach. Once the
                // unit beside it started scaling, the dose number stayed 17pt while
                // `mg/mL` grew to fill the row: at AX5 the vial strength read a
                // small `200` beside a huge `mg/mL`, and the weekly dose truncated
                // to `1…`. The value the user acts on became the smallest text on
                // the most safety-critical screen in the app, and then disappeared.
                .font(Theme.Typeface.cardTitle)
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
                // Without this the padding belongs to the container, not the
                // field, so only the ~20pt text frame focused it (finding F7).
                .contentShape(Rectangle())
                // ── THE INVARIANT ───────────────────────────────────────────────
                // This field may never display a number the engine did not use.
                //
                // It has now been broken twice. First by a quick-value chip that
                // wrote the binding while the text stayed put — field 100, engine
                // 300. Then by `clamp`: typing into a populated `mgWeek` field gave
                // text "100250" while `value` was silently clamped to the spec
                // ceiling of 1000, so the screen showed 100250 mg/week beside a
                // 2.500 mL draw computed from 1000. Measured 2026-08-02, on the real
                // build, at default type size.
                //
                // Two breaches on two different paths means the first fix was a patch
                // on one path. So the rule is enforced on BOTH edges below —
                // text -> value and value -> text — rather than at either call site.
                .onChange(of: text) { newValue in
                    guard !newValue.isEmpty else {
                        // EMPTY IS NOT ZERO. `entry = nil` is the field's own record
                        // that there is nothing in it; the binding takes 0 because
                        // that is what the engine has always been given for an empty
                        // field and `Double` cannot carry anything else. The value
                        // edge below reads `entry`, sees the field is empty and leaves
                        // the text alone — which is the loop this control used to run.
                        entry = nil
                        value = 0
                        return
                    }
                    // Unparseable is mid-entry ("." on its own). Leave the value
                    // alone; do not guess at what is being typed.
                    guard let typed = Double(newValue) else { return }
                    let clamped = clamp(typed)
                    entry = clamped
                    value = clamped
                    // Clamping used to be silent. If the engine refused the number,
                    // the field says so — visibly snapping mid-entry is the cost, and
                    // in a dosing app it beats a display that is 100x the dose.
                    if clamped != typed { text = format(clamped) }
                }
                // Anything that writes the binding from OUTSIDE this field — a quick
                // value chip, a stepper, a preset, a restored protocol — must be
                // reflected in the text.
                //
                // This no longer skips while focused. It used to, so that formatting
                // could not fight live typing, but that also meant the keyboard
                // toolbar's chips changed the engine and not the display — the
                // original bug, reachable again. The echo of the user's own keystroke
                // is identified precisely instead: if the text already parses to this
                // value there is nothing to correct, which leaves partial input like
                // "0." and "0.30" untouched (both parse equal to their value).
                .onChange(of: value) { newValue in
                    // EMPTY STAYS EMPTY, and this line is the fix. `entry == nil`
                    // means the user cleared the field; the binding is carrying 0
                    // because that is the only thing a `Double` can carry for "nothing
                    // entered", and formatting it back into the text is what put a `0`
                    // in front of everything typed next. Anything else written from
                    // outside — a chip, a stepper, a preset, a restored protocol —
                    // falls through and is still reflected, which is what this edge
                    // exists for.
                    if entry == nil && newValue == 0 { return }
                    entry = newValue
                    if Double(text) == newValue { return }
                    let formatted = format(newValue)
                    if text != formatted { text = formatted }
                }
                // The field opens on whatever the spec's default is, exactly as before:
                // a default of 0 still renders "0" rather than empty. Only a field the
                // USER has cleared is empty, because only that is a state the app knows
                // is empty rather than zero.
                .onAppear { entry = value; text = format(value) }
                // Focusing a populated field selects its contents, so typing
                // REPLACES rather than appends. Without it, typing 250 into a field
                // showing 100 gives 100250 — which is how the clamp breach above was
                // reached in the first place. Async because the field is not yet the
                // first responder on the same runloop pass as the focus change.
                .onChange(of: focused) { isFocused in
                    guard isFocused else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)),
                                                        to: nil, from: nil, for: nil)
                    }
                }

        }
    }

    // `stepButton` IS GONE, with `step_up_<key>` / `step_down_<key>`. It is recorded
    // here rather than silently deleted because the reason it existed is still true
    // and still honoured by what replaced it: a bare `Stepper` renders 46 x 32pt,
    // 12pt under the HIG floor (finding F6), which is why the ± were hand-rolled at
    // 44 x 44 with a real gap between two controls that act in opposite directions
    // on a dose. `TickDrum` is a single 44pt-tall drag target with an `.adjustable`
    // accessibility action, so the floor and the VoiceOver path both survive the
    // change; what does not survive is the −/+ pair squeezing the value cell on the
    // same line (F1, twice).

    private func clamp(_ d: Double) -> Double {
        guard let range else { return d }
        return min(max(d, range.lowerBound), range.upperBound)
    }
    /// The other half of the optional above: EMPTY RENDERS AS `""`, never as `"0"`.
    /// Every write to `text` in this view goes through here, so there is one place the
    /// empty state can be turned back into a digit and it does not.
    private func format(_ d: Double?) -> String {
        guard let d else { return "" }
        if d == d.rounded() { return String(Int(d)) }
        // Trim to ≤4 decimals and drop trailing zeros so the field never shows
        // float noise like "0.30000000000000004".
        var s = String(format: "%.4f", d)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
