import SwiftUI
import Charts

// ─── CyclePlotterScreen ──────────────────────────────────────────────────────
// Bespoke timeline editor: add compounds, set dose / dosing interval / cycle
// length, and render the projected plasma-level curve(s) from the ported PK model
// (CalculatorEngine.pkBuildEntries / pkTotalLevel — Bateman single-compartment).
// All-testosterone selections are calibrated to ng/dL (TESTO_NGDL_FACTOR); mixed
// selections plot raw model units, matching app.js.

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
            Text(vm.allTesto ? "Estimated level (ng/dL)" : "Estimated level (model units)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondaryLabel)

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
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
