import SwiftUI

// ─── CalculatorWebParity ─────────────────────────────────────────────────────
// The chrome the web wraps every calculator in, and that iOS never had. Built for
// T-01a — the twelve logged differences between the iOS TRT calculator and the
// web's — and shared, because the web shares them: one `TwoColCalcPage` renders
// all 21 calculator pages, so a control built for TRT here lands on the other
// fourteen iOS calculators the same way it does on the web.
//
// EVERY VALUE IN THIS FILE WAS READ FROM THE WEB'S OWN SOURCE OR MEASURED OFF THE
// REFERENCE FRAME, and the provenance is on each one. That is not ceremony:
// CLAUDE.md records two occasions where this app's behaviour was inferred from a
// document about the web rather than the web, and was wrong both times — once in a
// way that would have written a plausible wrong dose volume to every logged dose.
// Sources used here:
//   • `~/injectbuddy/public/app.js` — the live PWA bundle (IB_CALC_FORMULA,
//     ESTER_TYPE_OPTIONS, PLOT_CTA_CALC_IDS, the mode list, the drum value arrays).
//   • `~/injectbuddy/.design-sync/previews/*.tsx` — the component contracts.
//   • `injectbuddy-design-refs/screens/30-calc-trt-result.png` — colours, sampled
//     per-pixel rather than read out of the CSS cascade.

// MARK: - Section header  (T-01a difference #10)
//
// The web groups controls under a small-caps header — `SYRINGE SIZE` above the
// barrel row. iOS used sentence-case field labels throughout, so nothing grouped:
// every control read as a peer of every other control.
//
// `.textCase(.uppercase)` and not a pre-uppercased string, so VoiceOver announces
// the words rather than spelling out an acronym it does not recognise.
struct CalcSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .textCase(.uppercase)
            .font(Theme.Typeface.eyebrow)
            .tracking(0.6)
            .foregroundStyle(Theme.navy)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("section_\(title)")
    }
}

// MARK: - Mode switcher  (T-01a difference #1)
//
// The web leads every dose calculator with this: a recessed track holding one
// raised white pill that moves to the active segment. `ModeTab.tsx` is explicit
// that it "never toggles per-button fills" and that the accent shows up in the
// ACTIVE LABEL'S TONE, not as a fill — which is why this is not `SegmentedRow`
// with different colours.
//
// WHY IT MATTERS MORE THAN A CONTROL. iOS had no mode control at all, though the
// engine has stored a `mode` in every saved config since the port. The user could
// not switch how they think about the dose — and the app grew a SECOND CALCULATOR
// SCREEN (`.eod`) to hold a mode this control would have carried. See TASKS.md
// T-01c.
//
// Colours sampled from `30-calc-trt-result.png`: track #E6E6EE, active pill
// #FFFFFF. Not `.segmented` `Picker`: the system control cannot carry a wrapping
// label, and `mL → mg` at AX5 must wrap rather than truncate — a truncated mode
// name is a user calculating in the wrong direction.
struct ModeTab: View {
    struct Mode: Identifiable, Equatable {
        let label: String
        let value: String
        var id: String { value }
    }

    let modes: [Mode]
    @Binding var selection: String
    /// Identifier namespace, so two mode tabs on one screen never collide.
    var idPrefix: String = "mode_"

    var body: some View {
        // Same fallback-axis pattern as `SegmentedRow`: a row while the labels fit
        // side by side, a column the moment they do not. NO `lineLimit` anywhere —
        // `mL → mg` losing its arrow is a different instruction.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) { ForEach(modes) { segment($0) } }
            VStack(spacing: 2) { ForEach(modes) { segment($0) } }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.modeTrack)
        )
        .accessibilityIdentifier("\(idPrefix)tab")
    }

    private func segment(_ mode: Mode) -> some View {
        let isOn = selection == mode.value
        return Button {
            selection = mode.value
        } label: {
            Text(mode.label)
                .font(isOn ? Theme.Typeface.cardMeta.weight(.bold) : Theme.Typeface.cardMeta)
                // The accent lives in the LABEL's tone. `tealTextStrong` at 7.65:1,
                // never `accent` — #0FBCAD as text is 2.38:1 and fails at every size.
                .foregroundStyle(isOn ? Theme.navy : Theme.secondaryLabel)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget - 6)
                .padding(.horizontal, Theme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control - 2)
                        .fill(isOn ? Color.white : Color.clear)
                        .shadow(color: .black.opacity(isOn ? 0.10 : 0),
                                radius: 2, x: 0, y: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(idPrefix)\(mode.value)")
        .accessibilityLabel(mode.label)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Tick drum  (T-01a difference #7)
//
// `DrumPicker.tsx` calls this "the signature tactile control: a horizontal barrel
// of tick marks you drag, fling or click", and says every numeric calculator input
// on the web is one — weekly dose, vial strength, injection interval, GLP-1 dose.
//
// T-01a #7 describes it as a "tick ruler … beside the value showing the plausible
// range" and contrasts it with iOS's `−`/`+` steppers. That undersells what it is
// and the difference is worth stating: the web's ticks are the PRIMARY INPUT, not
// an ornament next to one. A stepper moves you one step from where you are; the
// drum shows you where you are on the range and lets you go anywhere on it in one
// gesture. Both readings agree on the defect, so #7 is built as the drum.
//
// THE STEPPERS ARE GONE, deliberately, and this is what replaces them — keeping
// both would put three ways to set one number on a dosing row. `step_up_<key>` /
// `step_down_<key>` are retired with them; `CalculatorWiringUITests` is updated in
// the same commit rather than left addressing controls that no longer exist.
//
// iOS 16 is the deployment target, so `.scrollTargetBehavior` (iOS 17) is not
// available and this cannot be a `ScrollView` with snapping. It is drawn and
// dragged directly, which is also what makes the accessibility shape right: ONE
// `.adjustable` element per drum, so VoiceOver swipes up/down through the values
// instead of meeting sixty tick buttons.
struct TickDrum: View {
    /// The values the drum snaps to, in ascending order.
    let values: [Double]
    @Binding var selection: Double
    /// Field key — the identifier namespace, so each drum is individually addressable.
    let key: String
    /// Label every Nth tick. 5 on the web's dense rulers (itemWidth 22).
    var labelEvery: Int = 5
    /// Point width of one tick cell. `DrumPicker.tsx`: "Real call sites pass 22
    /// (dense ruler) or 28 (sparse preset list)." A frozen point size is correct
    /// here and only here — this is a ruler, and a ruler whose gradations reflow
    /// with the type scale is not a ruler.
    var itemWidth: CGFloat = 22

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Continuous position of the current value in tick units. Continuous rather
    /// than an index because a TYPED value need not be on a tick — the web keeps
    /// `137` and lets the drum sit between gradations, and snapping the user's
    /// typed dose to the nearest 5 would be the calculator editing the number the
    /// user acts on.
    private var position: CGFloat {
        guard let first = values.first, let last = values.last, values.count > 1 else { return 0 }
        if selection <= first { return 0 }
        if selection >= last { return CGFloat(values.count - 1) }
        // Locate between the two bracketing ticks and interpolate.
        for i in 0..<(values.count - 1) where selection >= values[i] && selection <= values[i + 1] {
            let span = values[i + 1] - values[i]
            guard span > 0 else { return CGFloat(i) }
            return CGFloat(i) + CGFloat((selection - values[i]) / span)
        }
        return 0
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            // Where the current value sits: hard left, with the range running away
            // to the right, exactly as the reference frame renders it (the value box
            // is immediately to the left of the strip).
            let origin = -(position * itemWidth) + dragOffset

            ZStack(alignment: .leading) {
                ForEach(visibleIndices(width: width, origin: origin), id: \.self) { i in
                    tick(i, x: origin + CGFloat(i) * itemWidth)
                }
            }
            .frame(width: width, height: drumHeight, alignment: .leading)
            .clipped()
            // Fades out at the trailing edge instead of stopping dead, so the strip
            // reads as a barrel continuing past the screen rather than a list that
            // ended. Matches the reference frame, where the last labels dissolve.
            .mask(
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.62),
                    .init(color: .black.opacity(0), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { g in
                        isDragging = true
                        dragOffset = g.translation.width
                    }
                    .onEnded { g in
                        // Snap on release, never mid-drag: a value that jumps under
                        // the finger on a dosing control is unreadable while moving.
                        let moved = -(g.translation.width) / itemWidth
                        let target = (position + moved).rounded()
                        let clamped = min(max(target, 0), CGFloat(values.count - 1))
                        dragOffset = 0
                        isDragging = false
                        selection = values[Int(clamped)]
                    }
            )
        }
        .frame(height: drumHeight)
        // ONE element, `.adjustable`. Sixty tick buttons would be sixty VoiceOver
        // stops on a single field — the same defect class as `WidestWordProbe`
        // announcing every barrel option twice.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("drum_\(key)")
        .accessibilityLabel("Scale")
        .accessibilityValue(Self.format(selection))
        .accessibilityAdjustableAction { direction in
            let i = nearestIndex
            switch direction {
            case .increment: if i + 1 < values.count { selection = values[i + 1] }
            case .decrement: if i > 0 { selection = values[i - 1] }
            @unknown default: break
            }
        }
    }

    /// Grows with the type scale — the LABELS are Dynamic Type text, so the strip
    /// that holds them has to be. Only the tick PITCH is frozen (see `itemWidth`).
    private var drumHeight: CGFloat {
        typeSize >= .accessibility1 ? 56 : 38
    }

    private var nearestIndex: Int {
        guard !values.isEmpty else { return 0 }
        var best = 0
        var bestDelta = Double.greatestFiniteMagnitude
        for (i, v) in values.enumerated() {
            let d = abs(v - selection)
            if d < bestDelta { bestDelta = d; best = i }
        }
        return best
    }

    /// Only the ticks that can actually be seen are built. The vial-strength ruler
    /// is 41 ticks and the weekly-dose ruler is 201; building all of them for every
    /// layout pass on five fields is work nobody sees.
    private func visibleIndices(width: CGFloat, origin: CGFloat) -> [Int] {
        guard !values.isEmpty else { return [] }
        let firstVisible = Int(((-origin) / itemWidth).rounded(.down)) - 1
        let count = Int((width / itemWidth).rounded(.up)) + 3
        let lower = max(0, firstVisible)
        let upper = min(values.count - 1, firstVisible + count)
        guard lower <= upper else { return [] }
        return Array(lower...upper)
    }

    @ViewBuilder
    private func tick(_ i: Int, x: CGFloat) -> some View {
        let major = i % labelEvery == 0
        let isSelected = i == nearestIndex && !isDragging
        VStack(spacing: 3) {
            Rectangle()
                .fill(isSelected ? Theme.navy : Theme.fieldBorder.opacity(major ? 0.85 : 0.45))
                .frame(width: isSelected ? 2 : 1, height: major ? 12 : 7)
            if major {
                Text(Self.format(values[i]))
                    .font(.system(.caption2, design: .default,
                                  weight: isSelected ? .bold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Theme.navy : Theme.secondaryLabel)
                    // A gradation that wraps is not a gradation. This is the one
                    // place a single line is correct: the string is a number with no
                    // unit attached, so there is no value+unit pair to shear.
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(width: itemWidth, alignment: .top)
        .offset(x: x)
        .allowsHitTesting(false)
    }

    static func format(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%g", d)
    }

    // MARK: Value arrays, verbatim from `public/app.js`
    //
    // Rebuilt rather than derived from the iOS field's own range/step, because they
    // are not the same numbers: iOS's `strength` is `1...500 step 1` where the web's
    // ruler is `10…400 by 10`. The ruler shows the PLAUSIBLE range, which is a
    // narrower claim than what the field will accept.

    /// `WEEKLY_DOSE_STEPS` — [0] then 5…1000 by 5.
    static let weeklyDose: [Double] = [0] + stride(from: 5.0, through: 1000.0, by: 5).map { $0 }
    /// `VIAL_STRENGTH_VALUES` — [0] then 10…400 by 10.
    static let vialStrength: [Double] = [0] + stride(from: 10.0, through: 400.0, by: 10).map { $0 }
    /// `EVERY_N_DAYS_VALUES` — [0] then 1…14 by 0.5. 3.5 is legal and very common.
    static let everyNDays: [Double] = [0] + stride(from: 1.0, through: 14.0, by: 0.5).map { $0 }
    /// The mL→mg mode's draw volume. No web array — the web renders a plain input
    /// there — so this is derived from the barrel range at insulin-syringe pitch.
    static let mlDrawn: [Double] = stride(from: 0.0, through: 3.0, by: 0.05).map {
        (($0) * 100).rounded() / 100
    }
}

// MARK: - Compound combobox  (T-01a difference #2)
//
// The web's ester field is a real WAI-ARIA combobox — type to filter, arrows to
// move, Enter to pick — with a magnifier in the box. iOS had `.pickerStyle(.menu)`:
// no search, and a control with a KNOWN open defect (its selected value draws
// outside its own chrome at large text and lands on the label above it — measured,
// see `CalculatorScreen`).
//
// ONE CORRECTION TO T-01a #2, and it is worth having on the record because the
// difference list will be read again: it says the web has "the full compound list"
// against iOS's "fewer entries". THAT HALF IS WRONG. `app.js:81` defines
// `ESTER_TYPE_OPTIONS` as exactly seven strings, and `CalcConst.esterTypes` in this
// repo is the same seven in the same order. The real gap is search, the magnifier,
// and the keyboard-operable listbox — not the contents.
//
// A SHEET, not an inline dropdown. `.searchable` in a sheet is the native form of
// "type to filter a list" and it brings the system's own keyboard handling,
// cancellation and VoiceOver behaviour — DESIGN-PARITY §6, native controls stay
// native. It also sidesteps the menu-picker overlap defect entirely rather than
// inheriting it.
//
// ─── T-16: THE SAME CONTROL NOW CARRIES A NUMBER ─────────────────────────────
//
// The overlap defect was recorded against "12 picker fields across 8 calculators".
// Replacing the `stringPicker` sites with this closed the STRING half; the numeric
// `.picker` half — TRT's `Frequency`, the GLP-1 concentration and dose pairs, the
// peptide dose unit, the free-T unit, the steroid `Compound` picker that the
// measurement itself was taken on, and the plotter's own two menus — still drew
// outside their chrome.
//
// So the control is split in two: `Combobox` below is the face and the sheet, and
// `CompoundCombobox` / `ValueCombobox` are thin call-site wrappers over it. ONE
// control, per UX-UI-RULES §6 — what is fixed here is fixed on every calculator,
// and the string and numeric sites can no longer drift apart.
//
// IT TAKES AN INDEX, NOT A BINDING, and that is deliberate rather than awkward. A
// generic `Binding<Value>` would decide "which option is selected" by `==`, and on
// the numeric sites the value can arrive from a saved config rather than from the
// option array — so each wrapper owns its own idea of a match and hands down the
// index it settled on. `ValueCombobox` matches within a tolerance for exactly that
// reason; a `Double` that misses by a float ulp would otherwise render a control
// with no selected row.
struct Combobox: View {
    /// The field's own name — the sheet's title and the accessibility label.
    let label: String
    /// What the face shows. NEVER EMPTY at a numeric call site: a control with a
    /// value and a blank face is the same class of defect as a hidden number.
    let display: String
    /// Draws the face in the placeholder tone. Only true where there is genuinely
    /// no selection yet.
    let isPlaceholder: Bool
    let options: [String]
    /// Which row carries the checkmark, and what "already selected" means to the
    /// sheet. `nil` when the current value is not one of the options.
    let selectedIndex: Int?
    /// Field key, for the identifier. `control_<key>` matches what the menu picker
    /// published, so `CaptureCurrentState` and `PinnedBarReachabilityUITests` keep
    /// resolving this control under the name they already use.
    let key: String
    let onPick: (Int) -> Void

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.secondaryLabel)
                    .accessibilityHidden(true)
                Text(display)
                    .font(Theme.Typeface.cardTitle)
                    .foregroundStyle(isPlaceholder ? Theme.secondaryLabel : Theme.ink)
                    .multilineTextAlignment(.leading)
                    // The defect the menu picker has and this does not: the value
                    // takes the height it needs instead of drawing over the label.
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Theme.Spacing.sm)
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.secondaryLabel)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fieldChrome()
        // ONE element for VoiceOver: "Compound, Oxandrolone (Anavar), button".
        //
        // IT IS NOT ONE ELEMENT IN THE AUTOMATION SNAPSHOT, and that was measured
        // rather than assumed — twice, because the first assumption was wrong twice.
        // On Steroid Dosage at AX5 the snapshot carries the merged
        // `StaticText 'Oxandrolone (Anavar)' (16.0, 337.7, 370.0, 265.3)` — the whole
        // face's frame, not the text's — AND `Image 'magnifyingglass'
        // (38.0, 444.7, 50.7, 51.3)` as a separate leaf inside it. Neither
        // `accessibilityHidden(true)` on each glyph (present, below) nor
        // `accessibilityHidden(true)` on the whole face removed the Image. The glyph
        // sits LEFT of the text and nothing draws on anything; what the snapshot shows
        // is a child alongside the husk its own siblings collapsed into.
        //
        // The consequence is `LeafOverlapUITests`'s, not the user's, and it is carried
        // there as a declared debt with T-35 rather than by distorting this control to
        // suit the harness. Do not "fix" it by deleting the magnifier: it is the web's,
        // it is half of what makes this read as a search field, and it is not what is
        // wrong.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("control_\(key)")
        .accessibilityLabel(label)
        .accessibilityValue(isPlaceholder ? "" : display)
        .accessibilityAddTraits(.isButton)
        .sheet(isPresented: $isPresented) {
            ComboboxSheet(title: label, options: options,
                          selectedIndex: selectedIndex) { index in
                onPick(index)
            }
        }
    }
}

private struct ComboboxSheet: View {
    let title: String
    let options: [String]
    let selectedIndex: Int?
    let onPick: (Int) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    /// Filtered but still carrying the ORIGINAL index, so picking the third visible
    /// row after a search still writes the option the user is looking at. Filtering
    /// into a new array and reading its index back is the classic way to write the
    /// wrong value from a filtered list, and on a dosing control that is a wrong dose.
    private var filtered: [(index: Int, label: String)] {
        let all = options.enumerated().map { (index: $0.offset, label: $0.element) }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return all }
        return all.filter { $0.label.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text("No match for “\(query)”")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryLabel)
                } else {
                    ForEach(filtered, id: \.index) { row in
                        Button {
                            onPick(row.index)
                            dismiss()
                        } label: {
                            HStack {
                                Text(row.label)
                                    .foregroundStyle(Theme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: Theme.Spacing.sm)
                                if row.index == selectedIndex {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.tealTextStrong)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: Theme.minTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("option_\(row.label)")
                        .accessibilityAddTraits(row.index == selectedIndex
                                                ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("compound_cancel")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// The string call site — the ester list, and the plotter's compound menu, where the
/// stored value is an id rather than the label the user reads.
struct CompoundCombobox: View {
    let label: String
    /// Display strings, in order.
    let options: [String]
    /// What each option STORES, positionally paired with `options`. Defaults to the
    /// labels themselves, which is what the ester field wants.
    var values: [String]? = nil
    @Binding var selection: String
    let key: String

    private var stored: [String] { values ?? options }

    private var selectedIndex: Int? { stored.firstIndex(of: selection) }

    var body: some View {
        let index = selectedIndex
        Combobox(label: label,
                 display: index.map { options[$0] } ?? "Search \(label.lowercased())",
                 isPlaceholder: index == nil,
                 options: options,
                 selectedIndex: index,
                 key: key) { picked in
            selection = stored[picked]
        }
    }
}

/// The numeric call site — T-16. Everything `.pickerStyle(.menu)` rendered for a
/// `Double`: frequency, concentration, dose, dose unit, compound index, syringe
/// barrel.
///
/// THE MATCH IS TOLERANT, not `==`. These values round-trip through
/// `saved_dosages.config` as JSON numbers and arrive back as `Double`; an exact
/// comparison that missed by an ulp would show a control whose face said one thing
/// and whose sheet had nothing ticked. The tolerance is the same 0.0001 `SegmentedRow`
/// and `QuickValueRow` already use, so the three numeric selectors agree on what
/// "this option is the current one" means.
struct ValueCombobox: View {
    let label: String
    let options: [CalculatorInput.PickerOption]
    @Binding var selection: Double
    let key: String
    /// Suffix for a value that is NOT on the option list — see `display` below.
    /// `nil` where the bare number reads correctly on its own (a concentration, a
    /// dose), set where it does not: a lone `5` in a field called `Frequency` could
    /// be five days or five injections.
    var unit: String? = nil

    private var selectedIndex: Int? {
        options.firstIndex { abs($0.value - selection) < 0.0001 }
    }

    /// A value off the option list. It happens — a protocol read back from a saved
    /// config, or a plotter line seeded from a calculator whose interval is not one of
    /// the eight the web lists (T-17).
    private var unmatchedDisplay: String {
        let n = TickDrum.format(selection)
        return unit.map { "\(n) \($0)" } ?? n
    }

    var body: some View {
        let index = selectedIndex
        Combobox(label: label,
                 // NEVER a placeholder. A numeric field always holds a number, so a
                 // value off the option list is SHOWN — formatted — rather than
                 // replaced by prompt text. Hiding a dose the app is calculating with
                 // is the defect this file exists to remove.
                 display: index.map { options[$0].label } ?? unmatchedDisplay,
                 isPlaceholder: false,
                 options: options.map(\.label),
                 selectedIndex: index,
                 key: key) { picked in
            selection = options[picked].value
        }
    }
}

// MARK: - Formula card  (T-01a difference #4)
//
// "Show your working". `CalcFormula.tsx`: every calculator page ends with the
// actual arithmetic it ran, "so a user (or a clinician looking over their
// shoulder) can check the tool rather than trust it". On a screen whose whole
// output is a number somebody injects, that is not decoration.
//
// CONTENT IS NOT AUTHORED HERE. It is `IB_CALC_FORMULA` from `public/app.js`
// (~line 2478), transcribed per slug, so the card renders the same words the web
// renders. Where iOS has a calculator the web keys differently, the entry is
// absent rather than invented — a formula card that shows the wrong arithmetic is
// worse than none, because its whole purpose is to be checkable.
enum CalcFormulaCatalog {
    struct Formula {
        let formula: String
        /// `sym` — the coloured term — and `desc`, what it means.
        let legend: [(sym: String, desc: String)]
    }

    private static let unitsConversion = "converts mL to U-100 insulin-syringe units"
    private static let vialStrengthDesc = "concentration printed on the vial (mg/mL)"
    private static let glp1Legend: [(sym: String, desc: String)] = [
        ("dose", "your weekly dose (mg)"),
        ("concentration", "vial mg ÷ bacteriostatic water added (mL) = mg/mL"),
        ("× 100", unitsConversion),
    ]

    static func formula(for slug: CalculatorSlug) -> Formula? {
        switch slug {
        case .trt:
            return Formula(formula: "units = (per-shot dose ÷ vial strength) × 100", legend: [
                ("per-shot dose", "your weekly mg ÷ shots per week"),
                ("vial strength", vialStrengthDesc),
                ("× 100", unitsConversion),
            ])
        case .eod:
            return Formula(formula: "units = (per-shot dose ÷ vial strength) × 100", legend: [
                ("per-shot dose", "weekly mg ÷ shots per week (e.g. every-other-day)"),
                ("vial strength", vialStrengthDesc),
                ("× 100", unitsConversion),
            ])
        case .microdose:
            return Formula(formula: "units = (per-dose mg ÷ vial strength) × 100", legend: [
                ("per-dose mg", "the small daily/EOD amount you take"),
                ("vial strength", vialStrengthDesc),
                ("× 100", unitsConversion),
            ])
        case .semaglutide, .tirzepatide, .retatrutide:
            return Formula(formula: "units = (dose ÷ concentration) × 100", legend: glp1Legend)
        case .peptide:
            return Formula(formula: "units = (dose ÷ concentration) × 100", legend: [
                ("concentration", "peptide mg ÷ bacteriostatic water (mL), giving mg/mL"),
                ("dose", "your per-shot dose (in the same unit as the concentration)"),
                ("× 100", unitsConversion),
            ])
        case .reconstitution:
            return Formula(formula: "BAC water (mL) = (peptide mg × 1000) ÷ target concentration (mcg/mL)",
                           legend: [
                ("peptide mg × 1000", "converts the vial amount from mg to mcg"),
                ("target concentration", "the strength you want, in mcg/mL"),
                ("result", "how much bacteriostatic water to add to the vial"),
            ])
        // NOT TRANSCRIBED YET rather than guessed. `IB_CALC_FORMULA` carries more
        // entries than these; each one has to be read across individually and the
        // remaining slugs are covered by T-01b's per-screen comparisons, where the
        // rest of each screen is being read anyway.
        default:
            return nil
        }
    }
}

struct FormulaCard: View {
    let slug: CalculatorSlug

    var body: some View {
        if let f = CalcFormulaCatalog.formula(for: slug) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                CalcSectionHeader(title: "Formula")

                // The equation, in a well with a teal rule down its left edge —
                // the web's treatment, measured off the reference frame: well
                // #F5F5F5 inside a white card.
                HStack(alignment: .top, spacing: 0) {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: 4)
                        .accessibilityHidden(true)
                    Text(f.formula)
                        .font(Theme.Typeface.cardTitle)
                        .foregroundStyle(Theme.ink)
                        // A formula that truncates is a formula that lies. Wraps at
                        // every type size; the free-testosterone entry is long enough
                        // that this is load-bearing, not defensive.
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Theme.Spacing.md)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.formulaWell)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(f.legend, id: \.sym) { row in
                        // ONE Text, two runs. Not an HStack: the term and its
                        // description are one sentence, and an HStack would let the
                        // description wrap away from the term it defines.
                        // `.foregroundColor` and not `.foregroundStyle`, deliberately:
                        // the `ShapeStyle` overload on `Text` is iOS 17 and the
                        // deployment target is 16. It compiles either way at the VIEW
                        // level, which is why this is easy to get wrong — the failure
                        // only appears on the `Text + Text` form used here.
                        (Text(row.sym)
                            .font(Theme.Typeface.cardMeta.weight(.bold))
                            .foregroundColor(Theme.tealTextStrong)
                         + Text(" — \(row.desc)")
                            .font(Theme.Typeface.cardMeta)
                            .foregroundColor(Theme.secondaryLabel))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
            .accessibilityIdentifier("formula_card")
        }
    }
}

// MARK: - "See your levels over time"  (T-01a difference #3)
//
// `app.js` `PlotProtocolCTA`. A tinted card between the result and the save CTA
// that takes you into the cycle plotter with this protocol's context. iOS had
// nothing connecting the calculator and the plotter, though it ships both.
//
// TWO THINGS COPIED EXACTLY FROM THE SOURCE, because both are decisions and not
// styling: the SET of calculators that show it (`PLOT_CTA_CALC_IDS` — never BMI or
// free-T index, where a time series means nothing), and the wording split — the
// steady-dose testosterone calculators say "See your levels over time" because
// they are about serum curves, everything else says "Plot this protocol over time".
//
// THE NOTE THAT WAS HERE SAID "the web's href carries `?from=<calcId>` and the
// plotter reads it". **IT DOES NOT** — read on `feature/dosage-status-model`, the
// plotter's only use of that parameter is `get('from') === 'planner'`, which
// `from=trt` fails, after which it proceeds as if there were no query string. The
// correction and the whole reading are on `PlotterSeed`, which is where T-17 was
// built anyway: iOS now carries the compound, dose and interval across, through
// `AppRoute.plotter(seed:)`, using the web's own `mapDosage` formulas. Where iOS
// has no compound it can honestly draw, it carries nothing rather than guessing.
struct PlotLevelsCTA: View {
    let slug: CalculatorSlug
    let resultValid: Bool
    let action: () -> Void

    /// `PLOT_CTA_CALC_IDS`, verbatim. iOS has no `blend`/`ftv` slugs, so the list
    /// is the intersection — the omissions are missing calculators (T-01d), not a
    /// different decision about which screens get the link.
    static func shows(_ slug: CalculatorSlug) -> Bool {
        switch slug {
        case .trt, .microdose, .eod, .semaglutide, .tirzepatide, .retatrutide,
             .peptide, .reconstitution, .bpc157, .bpc157blend, .hcg:
            return true
        case .bmi, .freeTestIndex, .cyclePlotter, .steroid:
            return false
        }
    }

    private var title: String {
        switch slug {
        case .trt, .microdose, .eod: return "See your levels over time →"
        default: return "Plot this protocol over time →"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "chart.bar.fill")
                    // Inherits the label's font rather than freezing a point size —
                    // the Tools-at-AX5 failure was icons staying small while the
                    // text grew.
                    .foregroundStyle(Theme.tealTextStrong)
                    .accessibilityHidden(true)
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .font(Theme.Typeface.cardMeta.weight(.semibold))
            .foregroundStyle(Theme.tealTextStrong)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
            .padding(.vertical, Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(Theme.plotTint)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // `data-dim` on the web. Dimmed, NOT hidden and NOT disabled: the plotter is
        // a real destination whether or not this calculator currently has a valid
        // result, and a control that vanishes as you type is worse than one that
        // waits.
        .opacity(resultValid ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("cta_plot_levels")
        .accessibilityLabel(title.replacingOccurrences(of: " →", with: ""))
        .accessibilityAddTraits(.isButton)
    }
}
