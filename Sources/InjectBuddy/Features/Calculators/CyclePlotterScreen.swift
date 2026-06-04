import SwiftUI
import Charts

// ─── CyclePlotterScreen ──────────────────────────────────────────────────────
// Bespoke timeline editor: add compounds, set dose / dosing interval / cycle
// length, and render the projected plasma-level curve(s) from the ported PK model
// (CalculatorEngine.pkBuildEntries / pkTotalLevel — Bateman single-compartment).
// All-testosterone selections are calibrated to ng/dL (TESTO_NGDL_FACTOR); mixed
// selections plot raw model units, matching app.js.

struct CyclePlotterScreen: View {
    @StateObject private var vm = CyclePlotterViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                chartCard

                cycleLengthCard

                ForEach($vm.lines) { $line in
                    CompoundLineRow(line: $line,
                                    onRemove: { vm.remove(line) },
                                    canRemove: vm.lines.count > 1)
                }

                Button {
                    vm.addLine()
                } label: {
                    Label("Add compound", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
                .padding(.top, Theme.Spacing.xs)

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
                Text("\(vm.cycleWeeks) weeks")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
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
    let onRemove: () -> Void
    let canRemove: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Picker("Compound", selection: $line.compoundId) {
                    ForEach(PlotterCompound.all) { c in
                        Text(c.label).tag(c.id)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent)
                Spacer()
                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash").foregroundStyle(Theme.danger)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Dose (\(line.compound.unit))")
                        .font(.caption).foregroundStyle(Theme.secondaryLabel)
                    TextField("Dose", value: $line.dose, format: .number)
                        .keyboardType(.decimalPad)
                        .padding(.vertical, 8).padding(.horizontal, Theme.Spacing.sm)
                        .background(Theme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Frequency").font(.caption).foregroundStyle(Theme.secondaryLabel)
                    Picker("Frequency", selection: $line.freqDays) {
                        ForEach(CalcConst.freqs) { f in
                            Text(f.label).tag(f.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accent)
                }
            }

            Text("Half-life ~\(CalculatorEngine.fmt(line.compound.halfLife, 2)) d · tmax ~\(CalculatorEngine.fmt(line.compound.tmax, 2)) d")
                .font(.caption2).foregroundStyle(Theme.secondaryLabel)
        }
        .card()
    }
}
