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

                // AUDIT FINDING F12: at AX sizes the pinned result bar took ~60%
                // of the screen and hid the field being edited. Above AX1 the bar
                // collapses to the primary row + CTA and the full breakdown is
                // rendered here instead, inside the scroll, so no row is lost.
                if isAccessibilitySize, vm.result.isValid {
                    ResultCard(result: vm.result, barrelMl: barrelMl)
                }

                Text("Maths only — not medical advice.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.canvas)
        .safeAreaInset(edge: .bottom) { resultBar }
        .onAppear { vm.scale = settings.syringeScale }
        .onChange(of: settings.syringeScale) { vm.scale = $0 }
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
        VStack(spacing: Theme.Spacing.sm) {
            // Collapsed to a one-line summary while the keypad is up. At full
            // height the bar plus the keyboard covered 65% of the screen and cut
            // the field being edited in half (audit finding F11).
            ResultCard(result: vm.result,
                       isCompact: keyboard.isVisible || isAccessibilitySize,
                       barrelMl: barrelMl)

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
        .background(.bar)
    }
}

// MARK: - Result card

private struct ResultCard: View {
    let result: CalculatorResult
    var isCompact: Bool = false
    var barrelMl: Double?

    /// You cannot draw 1.2 mL into a 1 mL barrel. Surfaced as an icon PLUS text —
    /// WCAG 1.4.1: no state in this app is ever carried by colour alone, and least
    /// of all one that says the dose does not physically fit the syringe.
    private var overCapacity: Bool {
        guard let barrelMl, let draw = result.drawMl, result.isValid else { return false }
        // Tolerate float noise; a draw exactly equal to the barrel still fits.
        return draw > barrelMl + 0.0005
    }

    private var capacityNote: String? {
        guard overCapacity, let barrelMl, let draw = result.drawMl else { return nil }
        return String(format: "Draw of %.3f mL exceeds the %@ barrel — split the dose or choose a larger barrel.",
                      draw, barrelLabel(barrelMl))
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
                    SecondaryResultRow(label: primary.label, value: primary.value)
                    if let note = capacityNote { CapacityWarning(text: note) }
                }
            } else if result.isValid {
                ForEach(result.rows) { row in
                    if row.emphasis {
                        PrimaryResultRow(label: row.label, value: row.value)
                    } else {
                        SecondaryResultRow(label: row.label, value: row.value)
                    }
                }
                // Was an orphaned grey string with no label — at AX sizes it read
                // as a stray word ("Ideal") floating under the numbers. It is a
                // verdict on the draw volume, so it gets a label like every other row.
                if let line = result.scheduleLine {
                    SecondaryResultRow(label: "Volume", value: line)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(Theme.Typeface.eyebrow)
                .foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
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

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                Text(label).font(Theme.Typeface.resultLabel).foregroundStyle(Theme.secondaryLabel)
                Spacer(minLength: Theme.Spacing.sm)
                Text(value).font(Theme.Typeface.resultLabel.weight(.semibold))
                    .monospacedDigit().foregroundStyle(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(Theme.Typeface.resultLabel).foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value).font(Theme.Typeface.resultLabel.weight(.semibold))
                    .monospacedDigit().foregroundStyle(Theme.ink)
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
            .tint(Theme.tealTextStrong)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .fieldChrome()

        case let .stringPicker(options, _):
            Picker(field.label, selection: vm.stringBinding(field.key)) {
                ForEach(options, id: \.self) { opt in Text(opt).tag(opt) }
            }
            .pickerStyle(.menu)
            .tint(Theme.tealTextStrong)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .fieldChrome()

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
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .focused($focused)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
                // Without this the padding belongs to the container, not the
                // field, so only the ~20pt text frame focused it (finding F7).
                .contentShape(Rectangle())
                .onChange(of: text) { newValue in
                    if let d = Double(newValue) { value = clamp(d) }
                    else if newValue.isEmpty { value = 0 }
                }
                .onAppear { text = format(value) }

            if let unit {
                Text(unit)
                    .font(Theme.Typeface.cardMeta)
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize()
            }
            if let step {
                // A bare `Stepper` renders 46 × 32pt — 12pt under the HIG floor
                // (finding F6). Two explicit buttons give each half 44 × 44pt and
                // let us put a real gap between −/+, which act in opposite
                // directions on a dose.
                HStack(spacing: Theme.Spacing.sm) {
                    stepButton("minus") { value = clamp(value - step); text = format(value) }
                    stepButton("plus") { value = clamp(value + step); text = format(value) }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .fieldChrome(isFocused: focused)
        .onTapGesture { focused = true }
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
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
