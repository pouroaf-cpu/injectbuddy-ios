import SwiftUI

// ─── CalculatorScreen ────────────────────────────────────────────────────────
// Generic calculator form driven entirely by a CalculatorSpec. Renders each field
// from the spec, shows a pinned live ResultCard via .safeAreaInset(edge: .bottom),
// and saves the inputs as a protocol. The cycle-plotter slug routes to its bespoke
// screen instead.

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
                ForEach(vm.spec.fields) { field in
                    if shouldShow(field) {
                        FieldRow(field: field, vm: vm, focusedKey: $focusedKey)
                    }
                }

                // AUDIT FINDING F12: at AX sizes the pinned result bar took ~60%
                // of the screen and hid the field being edited. Above AX1 the bar
                // collapses to the primary row + CTA and the full breakdown is
                // rendered here instead, inside the scroll, so no row is lost.
                if vm.result.isValid {
                    // This card takes the bare `result_` identifiers for every row the
                    // pinned bar is NOT showing — which, once the gate can choose
                    // between four rungs, is most of them at most sizes. An identifier
                    // names the surface the user is reading, and which view that is
                    // now depends on a measurement. See `ResultCard.identifier(for:)`.
                    ResultCard(result: vm.result,
                               barrelMl: barrelMl,
                               pinnedLabels: pinnedLabels)
                }

                Spacer(minLength: Theme.Spacing.md)

                Text("Maths only — not medical advice.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .padding(Theme.Spacing.md)
            .frame(minHeight: geo.size.height, alignment: .top)
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
        // The candidate bars are measured HERE — inside the form, before the inset
        // that pins the real one. See `barCandidates`.
        .background(alignment: .bottom) { barCandidates }
        // ...and the content area is measured OUT HERE, outside the inset, because
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
        .toolbar { ToolbarItemGroup(placement: .keyboard) { keyboardAccessory } }
        .onAppear { vm.scale = settings.syringeScale }
        .onChange(of: settings.syringeScale) { vm.scale = $0 }
        .onChange(of: metrics) { latest in
            guard !keyboard.isVisible, let area = latest[BarMetrics.contentArea], area > 0 else { return }
            contentAreaAtRest = area
        }
    }

    // MARK: - The pinning gate
    //
    // T20. The bar took 52.3% of the content area at DEFAULT type size — measured off
    // IB2245749, not inferred: plate top pt 456.33, tab bar top pt 790.67, content
    // area 638.34pt between the header and the bar. It sheared the `Frequency` picker
    // through the middle of its control and left two of five inputs usable on a
    // standard phone at standard text.
    //
    // The previous gate was `typeSize >= .accessibility1`. That is a GUESS at where
    // the problem starts, and it guessed wrong in the direction that matters: the
    // screen it declared healthy was the one in the finding. A Dynamic Type category
    // is not the thing going wrong — the share of the screen the overlay owns is —
    // and the same category means different things on the fourteen calculators,
    // which carry between one and four result rows.
    //
    // So the bar measures what it would occupy and stands down when that is too much.
    // Three states rather than two, because "pinned or not" throws away the live
    // result on a screen where watching a dose change as you type it is the reason
    // this is not the web's "Show result" flow:
    //
    //   full      primary values + the weekly-total cross-check
    //   compact   the primary row alone — the form already used while the keypad is up
    //   unpinned  CTA only; the full breakdown is in the scroll, where it already is
    //
    // MEASURED, NOT CURRENT. Each candidate is laid out hidden and measured at its own
    // ideal height, so the decision does not depend on which state is showing. Gating
    // on the height of the bar as currently rendered would oscillate: full is too tall
    // -> drop to compact -> compact fits -> promote to full -> too tall, every frame.
    static let maxPinnedShare: CGFloat = {
        #if DEBUG
        // DEBUG-ONLY override, same purpose as FORCE_INLINE_FIELD: it lets a test
        // DRIVE the gate to each rung and assert what actually renders there, rather
        // than trusting a gate that has only ever been observed choosing one of them.
        // A gate whose other three branches have never been seen is three untested
        // branches on the screen that writes a protocol (BOARD §5.24).
        if let raw = ProcessInfo.processInfo.environment["BAR_SHARE_CAP"],
           let v = Double(raw), v > 0, v <= 1 {
            return CGFloat(v)
        }
        #endif
        // 0.40, and the reasoning is worth keeping because the number looks arbitrary
        // and the alternatives are worse.
        //
        // There is an IRREDUCIBLE FLOOR. `Add` plus the hero clearance plus padding
        // measures 18.79% of the content area at default and 22.56% at AX5, and D12
        // makes it mandatory, so no cap can reach below it. The gate is choosing
        // inside [18.79%, 52.40%], not [0%, 100%].
        //
        // Measured rungs at default size (TRT): full 52.40%, lead 35.44%,
        // compact 29.12%, unpinned 18.79%. A one-third cap leaves 14.54 points of
        // real budget and the `lead` rung needs 16.65 — it misses by 2.11 points, and
        // what pays is the dose: `compact` renders it as a small ink-coloured
        // secondary row instead of the 7.65:1 teal display face.
        //
        // Any cap in (35.44%, 52.40%) selects `lead` here. 0.40 is chosen for MARGIN
        // rather than fit — 0.36 would sit 0.6 points from a measured value and would
        // change rung on a font-metric revision. At AX5 `lead` measures 59.20%, so
        // 0.40 still stands the bar down there and T24's outcome is preserved by
        // measurement rather than by the Dynamic Type category that produced it.
        return 0.40
    }()

    /// The ladder, tallest first. The gate takes the tallest rung that fits.
    ///
    /// `lead` exists because the first cut of this gate went straight from `full` to
    /// `compact` and the frame said no. `compact` renders the dose as a small ink-
    /// coloured secondary row — which is right for the two seconds the keypad is up
    /// and the user is typing, and wrong as the RESTING presentation of the number
    /// they act on. It took `0.250 mL` from the 7.65:1 teal display face to the same
    /// weight as its own label. A gate that fixes a layout finding by shrinking the
    /// dose is trading one defect for a quieter one.
    enum PinnedMode: String, CaseIterable {
        /// Primary values plus the weekly-total cross-check.
        case full
        /// The lead figure alone, at full treatment — label above, display face, teal.
        case lead
        /// One small line. The keypad-up form.
        case compact
        /// CTA only.
        case unpinned
    }

    /// What the measurement says, ignoring the keypad.
    private var measuredMode: PinnedMode {
        // Before the first measurement lands, show what shipped. A screen that
        // flashes its result bar away on appear is worse than one frame of the old
        // layout.
        guard contentAreaAtRest > 0 else { return .full }
        return PinnedMode.allCases.first { mode in
            guard let h = metrics[mode.rawValue], h > 0 else { return false }
            return h / contentAreaAtRest <= Self.maxPinnedShare
        } ?? .unpinned
    }

    /// What actually renders. The keypad can only ever make the bar SMALLER —
    /// it never promotes a bar the measurement stood down.
    private var pinnedMode: PinnedMode {
        guard keyboard.isVisible else { return measuredMode }
        return measuredMode == .unpinned ? .unpinned : .compact
    }

    /// The labels the pinned bar is showing right now, derived from the SAME rule the
    /// bar itself renders from rather than restated here.
    private var pinnedLabels: Set<String> {
        guard pinnedMode != .unpinned else { return [] }
        return Set(ResultCard.rows(for: vm.result,
                                   isPinned: true,
                                   leadOnly: pinnedMode == .lead,
                                   isCompact: pinnedMode == .compact).map(\.label))
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
           let field = vm.spec.fields.first(where: { $0.key == key }),
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
        guard slug == .bmi else { return true }
        let imperial = vm.values.bool("imperial")
        switch field.key {
        case "heightCm", "weightKg": return !imperial
        case "heightFt", "heightIn", "weightLb": return imperial
        default: return true
        }
    }

    private var resultBar: some View {
        barBody(mode: pinnedMode)
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
            .overlay {
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

    /// The bar in a given state. One definition, used by the pinned instance and by
    /// all three hidden candidates, so a candidate cannot measure a layout that
    /// differs from the one it is predicting.
    @ViewBuilder
    private func barBody(mode: PinnedMode) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            switch mode {
            case .full:
                // The primary values plus the weekly-total cross-check.
                ResultCard(result: vm.result, isPinned: true, barrelMl: barrelMl)
            case .lead:
                // The lead figure, still at full treatment. What is given up is the
                // weekly total — the cross-check that confirms the app understood the
                // dose you typed — and the secondary values. Both are one scroll away
                // in the in-scroll card, which renders every row unconditionally.
                ResultCard(result: vm.result, isPinned: true, leadOnly: true, barrelMl: barrelMl)
            case .compact:
                // One line — label + value + unit, still unable to truncate. This is
                // the form the bar already took while the keypad was up (finding F11,
                // where bar + keyboard covered 65% of the screen and cut the field
                // being edited in half); the gate can now also choose it at rest.
                ResultCard(result: vm.result, isCompact: true, isPinned: true, barrelMl: barrelMl)
            case .unpinned:
                // Nothing. The full breakdown renders in the scroll, where it already
                // renders today — the user scrolls to the result instead of the
                // result covering the inputs.
                EmptyView()
            }

            // Titled "Add" to match the web, where the bottom nav's Add slot owns
            // saving. Kept ON the calculator for now rather than moved to the tab bar:
            // that needs the calculator to publish its readiness up to the shell (the
            // iOS analogue of the web's html.ib-add-ready), which is TASK 15 proper.
            // Success no longer jumps to the dashboard — it goes to confirm the start
            // day, which otherwise silently defaults to today.
            // Offline gates the SAVE only — never the maths. Evaluation is pure and
            // local, so the inputs and the result card stay fully live with no
            // connection; it's only persisting the protocol that needs the backend.
            PrimaryButton(
                title: vm.saveState == .saved ? "Added ✓" : "Add",
                isLoading: vm.saveState == .saving,
                isEnabled: vm.result.isValid && network.isOnline
            ) {
                Task {
                    await vm.save(backend: backend)
                    if vm.saveState == .saved, let id = vm.savedId {
                        navigator.push(.addConfirm(dosageId: id))
                    }
                }
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

    /// Daylight between this pinned bar and MainShell's hero circle.
    private static let heroClearance: CGFloat = 16

    // MARK: - Candidate measurement

    /// All three bar states, laid out hidden at their own ideal heights and measured.
    ///
    /// `fixedSize(vertical:)` is load-bearing, not tidiness. A `.background` is
    /// proposed the modified view's size, so without it a candidate taller than the
    /// form — which is the AX5 case, and the case the gate exists for — would be
    /// COMPRESSED to fit and measure smaller than it renders. The gate would then
    /// approve exactly the bar it was built to stand down, and it would do so
    /// silently.
    ///
    /// Hidden three ways on purpose. `.hidden()` alone leaves an element in the
    /// ACCESSIBILITY TREE (BOARD §5.6 — fourteen calculator rows sat swipeable at
    /// x = -290 on exactly that mistake), and these copies contain a second `Add`
    /// button. A VoiceOver user finding four Add buttons on a dosing screen, three of
    /// which write nothing, is the same class of defect as the one this task is
    /// fixing.
    private var barCandidates: some View {
        VStack(spacing: 0) {
            ForEach(PinnedMode.allCases, id: \.self) { mode in
                barBody(mode: mode).background { measure(mode.rawValue) }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func measure(_ key: String) -> some View {
        GeometryReader { g in
            Color.clear.preference(key: BarMetricsKey.self, value: [key: g.size.height])
        }
    }

    /// DEBUG-ONLY. Publishes the numbers the gate decided on, so a test asserts what
    /// the LAYOUT computed rather than a proxy the harness inferred.
    ///
    /// This is the shape BOARD §5.23 asks for. "Assert the bar looks about right" is
    /// the same class of check as "assert the displayed string contains no ellipsis" —
    /// it reads a layer that does not observe the thing being asserted. Here the test
    /// can compare the gate's own denominator and candidate heights against a band
    /// profile of the same frame, so the two disagree loudly if the proxy the gate
    /// reads ever stops being the content area.
    ///
    /// Zero-sized and out of the accessibility tree's way; not compiled into Release.
    @ViewBuilder
    private var gateProbe: some View {
        #if DEBUG
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityElement()
            .accessibilityIdentifier("bar_gate")
            .accessibilityLabel(
                "mode=\(pinnedMode.rawValue) measured=\(measuredMode.rawValue) "
                + "ax=\(isAccessibilitySize) "
                // The cap is published because it can be overridden from the
                // environment, and an override that silently fails to arrive is a run
                // that reports success while testing the default. That happened on
                // the first attempt at driving this gate.
                + String(format: "cap=%.4f area=%.2f ", Self.maxPinnedShare, contentAreaAtRest)
                + PinnedMode.allCases
                    .map { String(format: "%@=%.2f", $0.rawValue, metrics[$0.rawValue] ?? -1) }
                    .joined(separator: " "))
        #endif
    }
}

// MARK: - Measured layout plumbing

enum BarMetrics {
    /// Candidate heights are keyed by `PinnedMode.rawValue`, so a rung added to the
    /// ladder cannot be forgotten here.
    static let contentArea = "contentArea"
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

// MARK: - Result card

private struct ResultCard: View {
    let result: CalculatorResult
    var isCompact: Bool = false
    /// True for the bar pinned above the CTA, false for the full card in the scroll.
    /// The pinned instance shows the primary values plus the weekly-total
    /// cross-check; everything else lives in the scroll copy.
    var isPinned: Bool = false
    /// Pinned, but reduced to the LEAD figure alone — still label-above-value in the
    /// display face, so the number the user acts on keeps its size and its 7.65:1
    /// teal. This is the rung between `full` and the one-line `isCompact` form.
    var leadOnly: Bool = false
    var barrelMl: Double?

    /// You cannot draw 1.2 mL into a 1 mL barrel. Surfaced as an icon PLUS text —
    /// WCAG 1.4.1: no state in this app is ever carried by colour alone, and least
    /// of all one that says the dose does not physically fit the syringe.
    /// Rows the pinned bar keeps: every emphasised value, plus the weekly total.
    private var visibleRows: [ResultRow] {
        Self.rows(for: result, isPinned: isPinned, leadOnly: leadOnly, isCompact: isCompact)
    }

    /// Which rows a given instance shows. STATIC, and used by the screen as well as
    /// by the view, because the screen has to know which labels the pinned bar is
    /// currently displaying in order to hand out identifiers (see `identifier(for:)`)
    /// — and two copies of this rule would drift the moment a rung was added.
    static func rows(for result: CalculatorResult,
                     isPinned: Bool, leadOnly: Bool, isCompact: Bool) -> [ResultRow] {
        guard isPinned else { return result.rows }
        // The lead and compact rungs keep ONE row: the first emphasised figure. Not
        // "the first row" — an unemphasised row leading the list would put a
        // restatement of the inputs where the dose belongs.
        if leadOnly || isCompact {
            return result.rows.first(where: { $0.emphasis }).map { [$0] } ?? []
        }
        return result.rows.filter {
            $0.emphasis || $0.label.lowercased().contains("weekly total")
        }
    }

    /// Identifier namespace for THIS instance's rows.
    ///
    /// Both cards are on screen at once — the pinned bar and the copy inside the
    /// scroll — and both used to emit `result_<label>`. Measured: `result_Weekly
    /// total` resolved to two elements (y=641 hittable, y=896 not), and an ambiguous
    /// XCUIElement fails at resolution without ever reaching its assertion. That, not
    /// the ViewThatFits gap, is what killed `testQuickChip_fieldAndResultBothFollow`.
    ///
    /// `result_` names the PINNED bar deliberately: it is the surface the user always
    /// sees, so a test written against it is a test written against what is on
    /// screen. Both cards render the same `CalculatorResult` value, so they cannot
    /// disagree — the ambiguity was in addressing them, never in the numbers.
    /// Labels the PINNED bar is currently showing. Set by the screen on the in-scroll
    /// instance only.
    ///
    /// The rule used to be "`result_` names the pinned bar" and it was right while the
    /// bar always showed the same three rows. The measured gate broke that premise:
    /// the bar now shows all of them, one of them, or none, depending on a
    /// measurement — so `result_Weekly total` addressed ZERO elements the moment the
    /// gate picked the `lead` rung, and two wiring assertions went red on it. They
    /// were red about something true.
    ///
    /// The rule that survives is the one D8 was actually reaching for: AN IDENTIFIER
    /// NAMES THE SURFACE THE USER IS READING. So `result_<label>` follows the row.
    /// If the pinned bar is showing that row, the pinned bar answers to it; if the
    /// row only exists in the scroll, the scroll copy does. Still exactly one element
    /// per label, which is the property that matters — an ambiguous XCUIElement fails
    /// at resolution before any assertion runs.
    var pinnedLabels: Set<String> = []

    private func identifier(for label: String) -> String {
        if isPinned { return "result_" + label }
        return (pinnedLabels.contains(label) ? "detail_result_" : "result_") + label
    }

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
            if isCompact, result.isValid, let primary = result.rows.first(where: { $0.emphasis }) {
                // One line, still label + value + unit, still unable to truncate:
                // ViewThatFits stacks it rather than clipping the unit.
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    SecondaryResultRow(label: primary.label, value: primary.value,
                                       identifier: identifier(for: primary.label))
                    if let note = capacityNote { CapacityWarning(text: note) }
                }
            } else if result.isValid {
                // PINNED: the primary values plus the weekly total. The total is the
                // CROSS-CHECK, not a derived nicety — the user typed "400 mg/week"
                // and this is how they confirm the app understood them. Hiding the
                // figure that closes that loop to save vertical space is the wrong
                // trade in a dosing app.
                //
                // The rest — dose per injection, injections/week, volume verdict —
                // moves into the scroll. They restate the inputs, and the verdict
                // already has a louder channel: the over-capacity warning fires with
                // icon and text when it actually matters. Nothing is lost, only
                // relocated, and default now behaves like AX5 rather than inventing
                // a third mode.
                ForEach(visibleRows) { row in
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
                // The volume verdict lives in the scroll copy only. It already has
                // a louder channel when it matters — the over-capacity warning fires
                // with icon and text — so its quiet "Ideal" earns no pinned space.
                if let line = result.scheduleLine, !isPinned {
                    SecondaryResultRow(label: "Volume", value: line,
                                       identifier: identifier(for: "Volume"))
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

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(field.label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondaryLabel)

            content

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
            Picker(field.label, selection: vm.numberBinding(field.key)) {
                ForEach(options) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.tealTextStrong)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .fieldChrome()
            // Addressable so the reachability sweep can ask whether this control is
            // sheared by the pinned bar — `Frequency` is the control the T20 finding
            // names, and it is a menu picker, so a sweep covering only `field_*`
            // would have been green on the exact defect it was written for.
            // A menu picker collapses to ONE button, so the identifier does not
            // propagate to a row of children the way it would on a segmented row —
            // which is why those stay uncovered rather than being named unsafely.
            .accessibilityIdentifier("control_\(field.key)")

        case let .segmented(options, _):
            SegmentedRow(options: options, selection: vm.numberBinding(field.key))

        case let .stringPicker(options, _):
            Picker(field.label, selection: vm.stringBinding(field.key)) {
                ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
            }
            .pickerStyle(.menu)
            .tint(Theme.tealTextStrong)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .fieldChrome()
            .accessibilityIdentifier("control_\(field.key)")

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
private struct SegmentedRow: View {
    let options: [CalculatorInput.PickerOption]
    @Binding var selection: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(options) { opt in
                let isOn = abs(selection - opt.value) < 0.0001
                Button { selection = opt.value } label: {
                    Text(opt.label)
                        .font(isOn ? Theme.Typeface.cardMeta.weight(.bold)
                                   : Theme.Typeface.cardMeta)
                        .foregroundStyle(isOn ? .white : Theme.tealTextStrong)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.control)
                                .fill(isOn ? Theme.navy : Theme.accentSoft)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
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
        .padding(.horizontal, Theme.Spacing.md)
        .fieldChrome(isFocused: focused)
        .onTapGesture { focusedKey.wrappedValue = key }
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

    private var stacked: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            field
            HStack(spacing: Theme.Spacing.sm) {
                if let unit {
                    Text(unit)
                        .font(Theme.Typeface.cardMeta)
                        .foregroundStyle(Theme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("unit_\(key)")
                }
                Spacer(minLength: Theme.Spacing.sm)
                steppers
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var inline: some View {
        HStack(spacing: Theme.Spacing.sm) {
            field
            if let unit {
                Text(unit)
                    .font(Theme.Typeface.cardMeta)
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize()
                    // Paired with `field_<key>` so a test can compare the two
                    // geometrically. See DynamicTypeTruncationUITests — the value
                    // cell must never be narrower than its own unit.
                    .accessibilityIdentifier("unit_\(key)")
            }
            steppers
        }
    }

    @ViewBuilder
    private var steppers: some View {
        if let step {
            // A bare `Stepper` renders 46 x 32pt — 12pt under the HIG floor
            // (finding F6). Two explicit buttons give each half 44 x 44pt and let us
            // put a real gap between −/+, which act in opposite directions on a dose.
            HStack(spacing: Theme.Spacing.sm) {
                stepButton("minus", id: "step_down_\(key)") {
                    value = clamp(value - step); text = format(value)
                }
                stepButton("plus", id: "step_up_\(key)") {
                    value = clamp(value + step); text = format(value)
                }
            }
        }
    }

    private var field: some View {
        Group {
            TextField("0", text: $text)
                .accessibilityIdentifier("field_\(key)")
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
                    guard !newValue.isEmpty else { value = 0; return }
                    // Unparseable is mid-entry ("." on its own). Leave the value
                    // alone; do not guess at what is being typed.
                    guard let typed = Double(newValue) else { return }
                    let clamped = clamp(typed)
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
                    if Double(text) == newValue { return }
                    let formatted = format(newValue)
                    if text != formatted { text = formatted }
                }
                .onAppear { text = format(value) }
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

    /// `id` is per FIELD, not per symbol. Every ranged field on a screen renders a
    /// −/+ pair with the same "Decrease"/"Increase" labels, so `buttons["Increase"]
    /// .firstMatch` resolves to whichever field is highest in the tree — on TRT that
    /// is vial strength, and a test stepped that while asserting on weekly dose.
    private func stepButton(_ symbol: String, id: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.tealTextStrong)
                .frame(width: Theme.minTarget, height: Theme.minTarget)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .fill(Theme.accentSoft)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityLabel(symbol == "minus" ? "Decrease" : "Increase")
    }

    private func clamp(_ d: Double) -> Double {
        guard let range else { return d }
        return min(max(d, range.lowerBound), range.upperBound)
    }
    private func format(_ d: Double) -> String {
        if d == d.rounded() { return String(Int(d)) }
        // Trim to ≤4 decimals and drop trailing zeros so the field never shows
        // float noise like "0.30000000000000004".
        var s = String(format: "%.4f", d)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
