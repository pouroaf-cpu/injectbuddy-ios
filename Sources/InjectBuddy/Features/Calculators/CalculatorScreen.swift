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
    @Environment(\.backend) private var backend

    @StateObject private var vm: CalculatorViewModel

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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(vm.spec.fields) { field in
                    if shouldShow(field) {
                        FieldRow(field: field, vm: vm)
                    }
                }

                Text("Maths only — not medical advice.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.groupedBackground)
        .safeAreaInset(edge: .bottom) { resultBar }
        .onAppear { vm.scale = settings.syringeScale }
        .onChange(of: settings.syringeScale) { vm.scale = $0 }
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
        VStack(spacing: Theme.Spacing.sm) {
            ResultCard(result: vm.result)

            PrimaryButton(
                title: vm.saveState == .saved ? "Saved ✓" : "Save as protocol",
                isLoading: vm.saveState == .saving,
                isEnabled: vm.result.isValid
            ) {
                Task {
                    await vm.save(backend: backend)
                    if vm.saveState == .saved { navigator.select(.dashboard) }
                }
            }

            if case let .failed(msg) = vm.saveState {
                Text(msg).font(.caption).foregroundStyle(Theme.danger)
            }
        }
        .padding(Theme.Spacing.md)
        .background(.bar)
    }
}

// MARK: - Result card

private struct ResultCard: View {
    let result: CalculatorResult

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            if result.isValid {
                ForEach(result.rows) { row in
                    HStack {
                        Text(row.label)
                            .font(row.emphasis ? .subheadline.weight(.semibold) : .footnote)
                            .foregroundStyle(row.emphasis ? Theme.label : Theme.secondaryLabel)
                        Spacer()
                        Text(row.value)
                            .font(row.emphasis ? .title3.weight(.bold) : .subheadline)
                            .foregroundStyle(row.emphasis ? Theme.accent : Theme.label)
                            .monospacedDigit()
                    }
                }
                if let line = result.scheduleLine {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryLabel)
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

// MARK: - Field row

private struct FieldRow: View {
    let field: CalculatorInput
    @ObservedObject var vm: CalculatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(field.label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Theme.secondaryLabel)

            content

            if let help = field.help {
                Text(help).font(.caption2).foregroundStyle(Theme.secondaryLabel)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch field.kind {
        case let .number(unit, _, range, step):
            NumberField(value: vm.numberBinding(field.key), unit: unit, range: range, step: step)

        case let .picker(options, _):
            Picker(field.label, selection: vm.numberBinding(field.key)) {
                ForEach(options) { opt in
                    Text(opt.label).tag(opt.value)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, Theme.Spacing.md)
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

        case let .stringPicker(options, _):
            Picker(field.label, selection: vm.stringBinding(field.key)) {
                ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
            }
            .pickerStyle(.menu)
            .tint(Theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, Theme.Spacing.md)
            .background(Theme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))

        case .toggle:
            Toggle(field.label, isOn: vm.boolBinding(field.key))
                .tint(Theme.accent)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

        case let .stepperDays(_, range):
            Stepper(value: vm.numberBinding(field.key), in: range, step: 1) {
                Text("\(Int(vm.values.number(field.key))) days")
            }
        }
    }
}

// MARK: - Number field with optional stepper

private struct NumberField: View {
    @Binding var value: Double
    let unit: String?
    let range: ClosedRange<Double>?
    let step: Double?

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .onChange(of: text) { newValue in
                    if let d = Double(newValue) { value = clamp(d) }
                    else if newValue.isEmpty { value = 0 }
                }
                .onAppear { text = format(value) }
            if let unit {
                Text(unit).font(.footnote).foregroundStyle(Theme.secondaryLabel)
            }
            if let step {
                Stepper("", value: Binding(
                    get: { value },
                    set: { value = clamp($0); text = format(value) }
                ), step: step)
                .labelsHidden()
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
    }

    private func clamp(_ d: Double) -> Double {
        guard let range else { return d }
        return min(max(d, range.lowerBound), range.upperBound)
    }
    private func format(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(d)
    }
}
