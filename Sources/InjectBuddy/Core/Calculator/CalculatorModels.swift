import Foundation

// ─── CalculatorModels ────────────────────────────────────────────────────────
// Value-typed models that describe a calculator's input fields and its computed
// output. The generic CalculatorScreen renders a form from `[CalculatorInput]`
// and shows a `CalculatorResult`. Pure data — no SwiftUI here so the engine and
// tests can use it freely. Names are prefixed/owned by the Calculator module to
// avoid collisions with other features.

// MARK: - Input field model

/// One configurable field on a calculator form.
struct CalculatorInput: Identifiable, Equatable {
    /// Stable storage key — also the config key written to `saved_dosages.config`.
    let key: String
    let label: String
    let kind: Kind
    /// Optional helper text shown under the field.
    var help: String?

    var id: String { key }

    enum Kind: Equatable {
        /// A numeric entry. `unit` is shown as a suffix; `range`/`step` hint the UI.
        case number(unit: String?, defaultValue: Double, range: ClosedRange<Double>?, step: Double?)
        /// A segmented/menu picker of labeled options carrying a Double value.
        case picker(options: [PickerOption], defaultValue: Double)
        /// A picker of string-valued options (e.g. ester type).
        case stringPicker(options: [String], defaultValue: String)
        /// A boolean toggle.
        case toggle(defaultValue: Bool)
        /// A whole-number "every N days" stepper.
        case stepperDays(defaultValue: Double, range: ClosedRange<Double>)
    }

    /// A labeled option for a numeric picker (e.g. "EOD" → 3.5).
    struct PickerOption: Equatable, Identifiable {
        let label: String
        let value: Double
        var id: String { label }
    }

    // Convenience constructors keep the catalog terse.
    static func number(_ key: String, _ label: String, unit: String? = nil,
                       default def: Double, range: ClosedRange<Double>? = nil,
                       step: Double? = nil, help: String? = nil) -> CalculatorInput {
        CalculatorInput(key: key, label: label,
                        kind: .number(unit: unit, defaultValue: def, range: range, step: step),
                        help: help)
    }

    static func picker(_ key: String, _ label: String,
                       options: [PickerOption], default def: Double,
                       help: String? = nil) -> CalculatorInput {
        CalculatorInput(key: key, label: label,
                        kind: .picker(options: options, defaultValue: def), help: help)
    }

    static func stringPicker(_ key: String, _ label: String,
                             options: [String], default def: String,
                             help: String? = nil) -> CalculatorInput {
        CalculatorInput(key: key, label: label,
                        kind: .stringPicker(options: options, defaultValue: def), help: help)
    }

    static func toggle(_ key: String, _ label: String, default def: Bool,
                       help: String? = nil) -> CalculatorInput {
        CalculatorInput(key: key, label: label, kind: .toggle(defaultValue: def), help: help)
    }
}

// MARK: - Input value bag

/// Mutable, SwiftUI-bindable storage for the current values of a calculator's
/// fields. Numbers/options/days live in `numbers`, free strings in `strings`,
/// toggles in `bools`. The ViewModel seeds defaults from a spec and binds to it.
struct CalculatorValues: Equatable {
    var numbers: [String: Double] = [:]
    var strings: [String: String] = [:]
    var bools: [String: Bool] = [:]

    func number(_ key: String, _ fallback: Double = 0) -> Double { numbers[key] ?? fallback }
    func string(_ key: String, _ fallback: String = "") -> String { strings[key] ?? fallback }
    func bool(_ key: String, _ fallback: Bool = false) -> Bool { bools[key] ?? fallback }

    /// Seed defaults for every field on a spec.
    static func defaults(for fields: [CalculatorInput]) -> CalculatorValues {
        var v = CalculatorValues()
        for f in fields {
            switch f.kind {
            case let .number(_, def, _, _):           v.numbers[f.key] = def
            case let .picker(_, def):                  v.numbers[f.key] = def
            case let .stepperDays(def, _):             v.numbers[f.key] = def
            case let .stringPicker(_, def):            v.strings[f.key] = def
            case let .toggle(def):                     v.bools[f.key] = def
            }
        }
        return v
    }
}

// MARK: - Output model

/// One labeled output row in the result card.
struct ResultRow: Equatable, Identifiable {
    let label: String
    let value: String
    /// Primary rows render larger/accented.
    var emphasis: Bool = false
    var id: String { label }
}

/// The computed result of a calculator evaluation.
struct CalculatorResult: Equatable {
    var rows: [ResultRow]
    var isValid: Bool
    /// Optional schedule/explanatory line shown under the rows.
    var scheduleLine: String?
    /// Volume drawn into the barrel for ONE injection, in mL, when this calculator
    /// produces one. Structured rather than parsed back out of a formatted row —
    /// the barrel over-capacity check is a dosing safety check and must not depend
    /// on string formatting.
    var drawMl: Double?

    static let empty = CalculatorResult(rows: [], isValid: false, scheduleLine: nil, drawMl: nil)
}
