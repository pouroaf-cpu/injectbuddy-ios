import SwiftUI
import Charts

// ─── CyclePlotterScreen ──────────────────────────────────────────────────────
// Bespoke timeline editor: add compounds, set dose / dosing interval / cycle
// length, and render the projected plasma-level curve(s) from the ported PK model
// (CalculatorEngine.pkBuildEntries / pkTotalLevel — Bateman single-compartment).
//
// T-42 — THE CHART IS IN RELATIVE UNITS AND SAYS SO, because that is what the
// live plotter does. The heading and the unit are the web's own two strings,
// taken from `public/legacy/cycle-plotter/app.jsx` on `feature/dosage-status-model`:
//
//   :34   const METRIC_LABEL = { serum: 'Estimated serum level', … };
//   :555  // "rel." read as a truncation artefact next to the title. The serum
//   :556  // metric genuinely is a relative scale (see the FAQ: absolute ng/dL
//   :556  // needs per-compound Vd + bioavailability we don't have), so say so
//   :556  // in words.
//   :557  const unitLabel = metric === 'release' ? unit + '/day'
//   :557                  : metric === 'total' ? unit : 'relative units';
//
// So the axis is `Estimated serum level` / `relative units` — not a phrase
// invented here, and the web's comment is explicit that the long form is
// deliberate. This screen previously read `Estimated level (ng/dL)`.

/// The plotter's ported copy, DECLARED ONCE so a test can assert the same string
/// the view renders.
///
/// These were inline `Text` literals. A unit test cannot read a SwiftUI `Text`,
/// so a test asserting a literal it also declares is a check that cannot fail —
/// and this project has already found eight of those. Naming them here is what
/// makes `PlotterNoNgdlFactorTests`'s label assertions real: the view and the
/// test read the same declaration, so changing the wording back to `ng/dL`
/// fails a test rather than passing one.
///
/// Every string is the web's, quoted at its source below. None is authored here.
enum PlotterCopy {

    /// `public/legacy/cycle-plotter/app.jsx:34` —
    /// `const METRIC_LABEL = { serum: 'Estimated serum level', … }`.
    /// iOS plots only the `serum` metric, so this is the only one ported.
    static let axisTitle = "Estimated serum level"

    /// `public/legacy/cycle-plotter/app.jsx:557` — `… : 'relative units'`.
    /// The comment above it at :555 records that the abbreviated `rel.` was
    /// rejected because it "read as a truncation artefact next to the title",
    /// so the long form is the web's deliberate choice and is kept as-is.
    static let axisUnit = "relative units"

    /// `public/legacy/cycle-plotter/index.html:2296`, verbatim and unshortened.
    static let unitsFaqQuestion = "Why does the plotter use relative units instead of ng/dL?"

    /// `public/legacy/cycle-plotter/index.html:2297`, verbatim — plus the final
    /// sentence, which the visible copy drops and the FAQPage structured data at
    /// `:52` of the same file keeps. The extra sentence is ported because it is
    /// the one that says what the chart IS still good for, which is what makes
    /// this an explanation rather than a disclaimer.
    static let unitsFaqAnswer =
        "Absolute serum concentrations (in ng/dL) require compound-specific "
        + "pharmacokinetic parameters including volume of distribution and "
        + "bioavailability that are not reliably available for all compounds. "
        + "The relative units shown are directly proportional to your dose and "
        + "allow you to compare peak-to-trough ratios, evaluate injection "
        + "frequency, and estimate steady-state timing accurately. The shape "
        + "and timing of the curve is correct even if the absolute scale is not "
        + "calibrated to ng/dL."
}

struct CyclePlotterScreen: View {
    @StateObject private var vm: CyclePlotterViewModel

    /// T-17. `nil` from the drawer and the Tools hub, where nothing has been
    /// calculated; a compound line from a calculator's "See your levels over time".
    ///
    /// `@StateObject(wrappedValue:)` and not an `.onAppear` that mutates the model:
    /// the seed is the model's INITIAL state, and seeding it on appear would rebuild
    /// the curve twice and re-seed on every back-navigation, overwriting whatever the
    /// user had edited in between.
    init(seed: PlotterSeed? = nil) {
        _vm = StateObject(wrappedValue: CyclePlotterViewModel(seed: seed))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                chartCard

                cycleLengthCard

                // INDEXED, so each row's controls get their own identifier. Two rows
                // publishing `control_plotCompound` is an ambiguous query, and an
                // ambiguous identifier fails at RESOLUTION, before any assertion runs.
                ForEach(Array(vm.lines.enumerated()), id: \.element.id) { index, line in
                    CompoundLineRow(line: $vm.lines[index],
                                    index: index,
                                    onRemove: { vm.remove(line) },
                                    canRemove: vm.lines.count > 1)
                }

                Button {
                    vm.addLine()
                } label: {
                    // T-31 — `Theme.accent` (#0FBCAD) was the foreground here. It is
                    // 2.38:1 on white and UX-UI-RULES §5 makes it FILL ONLY, never a
                    // text or glyph colour. `tealTextStrong` is 7.65:1 and is the
                    // token for teal text.
                    Label("Add compound", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.tealTextStrong)
                }
                .padding(.top, Theme.Spacing.xs)
                .accessibilityIdentifier("plotAddCompound")

                Text("Maths only — not medical advice. Plasma levels are population-model estimates with wide individual variation.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.groupedBackground)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // TWO SEPARATE LEAVES, each carrying its own identifier, and NOT one
            // identifier on the enclosing stack. An identifier set on a container
            // propagates to its descendants and overwrites the ones they set for
            // themselves — the `ModeTab` trap in CLAUDE.md — so a wrapper here would
            // make both strings unobservable and the UI test's failure would read as
            // "the axis is missing" rather than "the probe is wrong".
            //
            // STACKED, not the web's inline `<h2>` + `<span>`. UX-UI-RULES §2 forbids
            // truncation, and `Estimated serum level` beside `relative units` on one
            // line has nowhere to go at AX5. Vertical is the same two strings, honestly.
            VStack(alignment: .leading, spacing: 2) {
                Text(PlotterCopy.axisTitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plotAxisTitle")
                Text(PlotterCopy.axisUnit)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plotAxisUnit")
            }

            if vm.series.isEmpty {
                Text("Add a compound with a dose to plot")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart {
                    ForEach(vm.series) { s in
                        ForEach(s.points) { p in
                            LineMark(
                                x: .value("Day", p.day),
                                y: .value("Level", p.level)
                            )
                            .foregroundStyle(by: .value("Compound", s.label))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                }
                .chartXAxisLabel("Days")
                .frame(height: 240)
            }

            relativeUnitsExplainer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: - "Why relative units?"  (T-42, ported under T-13's filter)
    //
    // T-13 decided the calculator FAQ is KEPT, FILTERED: an entry survives if it
    // states a hazard, EXPLAINS A NUMBER THE SCREEN SHOWS, or documents how to
    // enter something unusual. This is the second clause exactly — it is the
    // clearest thing either codebase says about what its own chart means.
    //
    // VERBATIM from the live plotter, `public/legacy/cycle-plotter/index.html`
    // on `feature/dosage-status-model`:
    //
    //   :2296  <div class="faq-q">Why does the plotter use relative units instead
    //          of ng/dL?</div>
    //   :2297  <div class="faq-a">Absolute serum concentrations (in ng/dL) require
    //          compound-specific pharmacokinetic parameters including volume of
    //          distribution and bioavailability that are not reliably available for
    //          all compounds. The relative units shown are directly proportional to
    //          your dose and allow you to compare peak-to-trough ratios, evaluate
    //          injection frequency, and estimate steady-state timing accurately.</div>
    //
    // THE LAST SENTENCE COMES FROM THE SAME FILE AT :52, not from here. The page
    // carries this answer twice — once as visible copy at :2296-2297 and once as
    // FAQPage structured data at :49-52 — and the structured-data copy has one
    // extra sentence the visible one drops: "The shape and timing of the curve is
    // correct even if the absolute scale is not calibrated to ng/dL." It is kept
    // because it is the sentence that tells a user what the chart IS still good
    // for, which is the difference between an explanation and a disclaimer. Both
    // strings are the web's; neither is written here.
    //
    // PLACED INSIDE THE CHART CARD rather than at the foot of the screen, under
    // the curve it is about. The existing bottom-of-screen note is a medical
    // disclaimer about the whole tool; this answers the axis, so it sits with it.
    // Presentation follows the established explanatory-copy pattern —
    // `.caption2` / `Theme.secondaryLabel`, as `CalculatorScreen`'s per-field
    // `help` does. (The calendar's "How it works", cited as precedent in T-13,
    // is not built on iOS yet — nothing in `Sources/` matches that string — so
    // this is the first ported FAQ entry and the field `help` style is the only
    // real precedent to follow.)
    private var relativeUnitsExplainer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // The web's question, verbatim and unshortened. A tidied-up "Why relative
            // units?" would be a phrase written here, and the point of porting this
            // entry is that neither half is authored on the iOS side.
            Text(PlotterCopy.unitsFaqQuestion)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("plotUnitsFaqQuestion")

            Text(PlotterCopy.unitsFaqAnswer)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("plotUnitsFaqAnswer")
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var cycleLengthCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Text("Cycle length")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Theme.secondaryLabel)
                Spacer()
                // T-31, and this is the one that matters: a VALUE+UNIT PAIR in a
                // 2.38:1 teal. `tealTextStrong`, 7.65:1. No `lineLimit` — §2.
                Text("\(vm.cycleWeeks) weeks")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.tealTextStrong)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("plotCycleWeeks")
            }
            Stepper(value: $vm.cycleWeeks, in: 1...52) {
                EmptyView()
            }
            .labelsHidden()
        }
        .card()
    }
}

// MARK: - Compound line row

private struct CompoundLineRow: View {
    @Binding var line: PlotterLine
    /// Position in the list — the identifier namespace for this row's controls.
    let index: Int
    let onRemove: () -> Void
    let canRemove: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                // T-16 — the plotter's own two menu pickers, the eleventh and twelfth
                // of the twelve the overlap finding was recorded against. Same defect,
                // same control, and worse here than on a calculator: this list holds
                // `Nandrolone Phenylpropionate (NPP)` and `TB-500 (Thymosin β-4)`,
                // which are longer than the `Oxandrolone (Anavar)` the overlap was
                // measured on. See `Combobox` in CalculatorWebParity.
                //
                // `.tint(Theme.accent)` went with the picker and is NOT carried over.
                // `.tint` on a menu picker colours its VALUE TEXT, and #0FBCAD is
                // 2.38:1 on white — UX-UI-RULES §5 makes the accent fill-only. The
                // combobox draws its value in `Theme.ink`.
                CompoundCombobox(label: "Compound",
                                 options: PlotterCompound.all.map(\.label),
                                 values: PlotterCompound.all.map(\.id),
                                 selection: $line.compoundId,
                                 key: "plotCompound_\(index)")
                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash").foregroundStyle(Theme.danger)
                    }
                    .accessibilityLabel("Remove compound")
                    .accessibilityIdentifier("plotRemove_\(index)")
                }
            }

            // STACKED, NOT SIDE BY SIDE — and this is a regression THIS commit caused,
            // read off `28-plotter-seeded-from-trt-default.png` and fixed rather than
            // filed.
            //
            // These two sat in an `HStack`, so each got half the width. The menu picker
            // that used to hold `Frequency` drew its value on ONE line whatever the
            // width; the combobox that replaced it obeys §9 — the container grows, the
            // text does not shrink or clip — so in a half-width column
            // `Twice per week (2x/wk)` wrapped to FIVE LINES at DEFAULT size, against a
            // one-line `Dose` field beside it. Not hidden, and still wrong: it is the
            // whole row's height for one label, on the screen the levels link lands on.
            //
            // Full width is what the labels need — `PLOTTER_FREQS` runs to
            // `Three times/day (TID)` and `Every 2 weeks (E2W)` — and stacked is what
            // UX-UI-RULES §4 calls a label above its field anyway. NOT `ViewThatFits`:
            // a `Text`'s ideal width is its UNWRAPPED width, so the fit test would have
            // taken the column branch at every size regardless, which is the exact trap
            // `MinimumWidthAsIdeal` in `CalculatorScreen` documents. Choosing the column
            // outright is the same layout, honestly.
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Dose (\(line.compound.unit))")
                        .font(.caption).foregroundStyle(Theme.secondaryLabel)
                    TextField("Dose", value: $line.dose, format: .number)
                        .keyboardType(.decimalPad)
                        // Addressable per row, so T-17's proof can read the dose the
                        // calculator handed over rather than be read off a photograph.
                        .accessibilityIdentifier("plotDose_\(index)")
                        .padding(.vertical, 8).padding(.horizontal, Theme.Spacing.sm)
                        .background(Theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Frequency").font(.caption).foregroundStyle(Theme.secondaryLabel)
                    // `unit: "days"` because a T-17 seed can carry an interval that is
                    // not one of the eight listed — a TRT protocol on `every 5 days`
                    // is legal and common — and a bare `5` in a field called
                    // Frequency could be read as five injections.
                    ValueCombobox(label: "Frequency",
                                  options: PlotterCompound.freqs,
                                  selection: $line.freqDays,
                                  key: "plotFreq_\(index)",
                                  unit: "days")
                }
            }

            Text("Half-life ~\(CalculatorEngine.fmt(line.compound.halfLife, 2)) d · tmax ~\(CalculatorEngine.fmt(line.compound.tmax, 2)) d")
                .font(.caption2).foregroundStyle(Theme.secondaryLabel)
        }
        .card()
    }
}
