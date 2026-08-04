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
    /// Optional one-tap values shown as buttons under a numeric field. For dose
    /// fields, where a user picks from a handful of round numbers far more often
    /// than they type an arbitrary one. Typing still works — these are a shortcut,
    /// never the only way in.
    var quick: [Double] = []
    /// The tick-ruler gradations shown beside a numeric field — the web's
    /// `DrumPicker` values (T-01a #7). EMPTY MEANS NO RULER, which is the honest
    /// default: a scale is a claim about the plausible range of a quantity, and the
    /// web only makes that claim where it has an array for it. Never derived from
    /// `range`/`step` — those are what the field ACCEPTS, which is a wider and
    /// different thing (iOS's vial strength accepts 1…500 by 1; the web's ruler
    /// shows 10…400 by 10).
    var drum: [Double] = []
    /// Set when this field's number is READ AND WRITTEN IN A UNIT THE USER PICKS with
    /// another field. See `UnitScaling`. Nil on every field that has one fixed unit,
    /// which is all of them but the peptide dose today.
    var unitScaling: UnitScaling?

    var id: String { key }

    enum Kind: Equatable {
        /// A numeric entry. `unit` is shown as a suffix; `range`/`step` hint the UI.
        case number(unit: String?, defaultValue: Double, range: ClosedRange<Double>?, step: Double?)
        /// A menu picker of labeled options carrying a Double value.
        case picker(options: [PickerOption], defaultValue: Double)
        /// The same, rendered as an always-visible row of buttons rather than a
        /// menu. For short option sets that are worth one tap — the syringe barrel.
        case segmented(options: [PickerOption], defaultValue: Double)
        /// A picker of string-valued options (e.g. ester type).
        case stringPicker(options: [String], defaultValue: String)
        /// A string-valued SEGMENTED control whose options carry a display label
        /// separate from the stored value — the calculator's dosing MODE, where the
        /// label is `Every N Days` and the value written to `config.mode` is `ndays`.
        ///
        /// A separate case rather than a flag on `stringPicker`, because the two are
        /// not the same control: this one is always visible and switches which OTHER
        /// FIELDS the form shows (see `CalculatorScreen.shouldShow`), which a menu
        /// picker of strings never did.
        case modePicker(options: [ModeOption], defaultValue: String)
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

    /// A labeled option for the mode switcher. The VALUE is what reaches
    /// `saved_dosages.config.mode` and it must match the web's string exactly —
    /// `ndays` / `perweek` / `ml2mg`, from `app.js`. The database de-duplicates on
    /// the whole config, so a mode spelled differently is a different protocol.
    struct ModeOption: Equatable, Identifiable {
        let label: String
        let value: String
        var id: String { value }
    }

    // Convenience constructors keep the catalog terse.
    static func number(_ key: String, _ label: String, unit: String? = nil,
                       default def: Double, range: ClosedRange<Double>? = nil,
                       step: Double? = nil, help: String? = nil,
                       quick: [Double] = [],
                       drum: [Double] = [],
                       unitScaling: UnitScaling? = nil) -> CalculatorInput {
        CalculatorInput(key: key, label: label,
                        kind: .number(unit: unit, defaultValue: def, range: range, step: step),
                        help: help, quick: quick, drum: drum, unitScaling: unitScaling)
    }

    static func segmented(_ key: String, _ label: String,
                          options: [PickerOption], default def: Double,
                          help: String? = nil) -> CalculatorInput {
        CalculatorInput(key: key, label: label,
                        kind: .segmented(options: options, defaultValue: def), help: help)
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

    static func modePicker(_ key: String, _ label: String,
                           options: [ModeOption], default def: String,
                           help: String? = nil) -> CalculatorInput {
        CalculatorInput(key: key, label: label,
                        kind: .modePicker(options: options, defaultValue: def), help: help)
    }

    static func toggle(_ key: String, _ label: String, default def: Bool,
                       help: String? = nil) -> CalculatorInput {
        CalculatorInput(key: key, label: label, kind: .toggle(defaultValue: def), help: help)
    }
}

// MARK: - Unit-dependent fields  (T-41)

/// Declares that a numeric field's VALUE AND ITS BOUNDS are expressed in a unit the
/// user chooses with ANOTHER field on the same form.
///
/// ── WHY THIS SHAPE ──────────────────────────────────────────────────────────────
/// `CalculatorInput.number` bakes ONE `range`, `step` and `quick` set into the spec at
/// `CalculatorCatalog`. The peptide dose's bounds are not one set: `0…20000 mcg` is
/// `0…20 mg`, and the chips `250 · 500 · 750 · 1000 · 2000` are nonsense in mg. Before
/// T-41 the picker changed the unit and NOTHING else — 500 mcg became 500 mg, the
/// engine computed a draw volume, units, weekly total and doses-per-vial for a dose
/// 1000× too large, and every figure on the screen was internally consistent with it.
///
/// The alternatives, and why not:
///   • a branch in `CalculatorScreen` (`if slug == .peptide`) — the screen renders
///     fifteen calculators from these specs and must not know about any of them;
///   • converting the value without moving the bounds — the fix the Windows side
///     flagged as insufficient, and it is: with a single `0…10000`, iOS's own default
///     of 500 in mg mode is 25× the web's entire allowable maximum;
///   • a second spec per unit — two specs to keep in step, and `configJSON()` reads
///     the key set off the spec, so a drifting second copy is a different protocol.
///
/// ── TWO OPERATIONS, DELIBERATELY SEPARATE ───────────────────────────────────────
///   • the SPEC scales — `CalculatorInput.resolved(against:)`, pure, no side effects,
///     safe to call on every render;
///   • the VALUE converts — `CalculatorSpec.convertingUnits(from:to:)`, applied ONCE
///     by `CalculatorViewModel` on the transition itself.
/// A resolver that also converted would rescale the number on every layout pass, and a
/// converter that ran on every render is how a field ends up showing a number the
/// engine never saw — the invariant `NumberField.field` is built around.
///
/// ── PER FIELD, NOT PER CALCULATOR ───────────────────────────────────────────────
/// Declared on the `CalculatorInput` so the next field that needs it declares it too
/// rather than adding a slug branch anywhere. T-43 is the same defect on the Free T
/// Index total-testosterone picker with a factor of 28.84.
///
/// Describes a BINARY selector — base unit or the one alternate. A third unit needs a
/// different type, not another field on this one.
struct UnitScaling: Equatable {
    /// Key of the picker that chooses the unit.
    let selectorKey: String
    /// The selector value at which the field's own spec numbers are already correct.
    /// The field's declared `unit` is therefore the BASE unit.
    let baseSelectorValue: Double
    /// Unit suffix shown, and announced, when the selector is off base.
    let alternateUnit: String
    /// Base units per alternate unit — 1000, because 1 mg is 1000 mcg. The alternate
    /// reading is `base / factor`.
    let factor: Double
    /// Decimals each side rounds to. These are `app.js`'s, verbatim from
    /// `PeptidePage.handleUnitToggle` (`public/app.js:6237-6245` on
    /// `feature/dosage-status-model`):
    ///   `newUnit === 'mg' ? Number((dosePerInj / 1000).toFixed(3))`
    ///                     `: Number((dosePerInj * 1000).toFixed(0))`
    /// Read from the source, not from a document about it.
    let baseDecimals: Int
    let alternateDecimals: Int

    func isBase(_ selector: Double) -> Bool { selector == baseSelectorValue }

    /// mcg → mg.
    func toAlternate(_ v: Double) -> Double { Self.rounded(v / factor, alternateDecimals) }
    /// mg → mcg.
    func toBase(_ v: Double) -> Double { Self.rounded(v * factor, baseDecimals) }

    func convert(_ v: Double, toBase wantsBase: Bool) -> Double {
        wantsBase ? toBase(v) : toAlternate(v)
    }

    /// `toFixed(n)` — round half away from zero at `n` decimals, then back to a Double.
    ///
    /// The rounding is what makes the trip REVERSIBLE, and reversibility is the whole
    /// test: 500 → 0.5 → 500 and 0.5 → 500 → 0.5. Divide-then-multiply without it
    /// leaves float residue that a later comparison reads as a different dose.
    static func rounded(_ v: Double, _ decimals: Int) -> Double {
        let f = pow(10.0, Double(decimals))
        return (v * f).rounded() / f
    }
}

extension CalculatorInput {
    /// This field expressed in the unit currently selected. Identity when the field has
    /// no `unitScaling` or the selector is at its base value, so it is a no-op for the
    /// fourteen calculators that do not use it.
    ///
    /// Scales EVERYTHING the field claims about the quantity — the bounds the entry
    /// clamps to, the step, the quick chips and the tick ruler — because a number is
    /// only ever as safe as the range around it. `0.5 mg` under a step of 1 and a
    /// ceiling of 10000 is a different wrong answer, not a fix.
    func resolved(against values: CalculatorValues) -> CalculatorInput {
        guard let s = unitScaling,
              case let .number(_, def, range, step) = kind,
              !s.isBase(values.number(s.selectorKey, s.baseSelectorValue))
        else { return self }

        let scaledRange = range.map { r -> ClosedRange<Double> in
            let a = s.toAlternate(r.lowerBound), b = s.toAlternate(r.upperBound)
            // `min`/`max` rather than `a...b`: a ClosedRange traps on an inverted
            // bound, and a crash on a dosing screen is not a better failure than a
            // wide range.
            return Swift.min(a, b)...Swift.max(a, b)
        }
        return CalculatorInput(
            key: key, label: label,
            kind: .number(unit: s.alternateUnit,
                          defaultValue: s.toAlternate(def),
                          range: scaledRange,
                          step: step.map(s.toAlternate)),
            help: help,
            quick: quick.map(s.toAlternate),
            drum: drum.map(s.toAlternate),
            unitScaling: s)
    }
}

extension CalculatorSpec {
    /// The form's fields in the units currently selected. What the screen renders.
    func resolvedFields(_ values: CalculatorValues) -> [CalculatorInput] {
        fields.map { $0.resolved(against: values) }
    }

    /// The number a unit-scaled field must now show, when its selector has just moved.
    ///
    /// Returns nil when no selector moved, which is every change but the flip — the
    /// caller must not write `values` back on an ordinary keystroke.
    ///
    /// THIS CONVERTS, IT DOES NOT CLAMP. A clamp passes a one-way test (`500 mcg` →
    /// something smaller in mg) and fails the trip: the pass condition is that
    /// mcg → mg → mcg returns the original number and mg → mcg → mg does too.
    func convertingUnits(from old: CalculatorValues, to new: CalculatorValues) -> CalculatorValues? {
        var out = new
        var changed = false
        for field in fields {
            guard let s = field.unitScaling else { continue }
            let was = old.number(s.selectorKey, s.baseSelectorValue)
            let now = new.number(s.selectorKey, s.baseSelectorValue)
            guard was != now else { continue }
            out.numbers[field.key] = s.convert(new.number(field.key), toBase: s.isBase(now))
            changed = true
        }
        return changed ? out : nil
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
            case let .segmented(_, def):               v.numbers[f.key] = def
            case let .stepperDays(def, _):             v.numbers[f.key] = def
            case let .stringPicker(_, def):            v.strings[f.key] = def
            case let .modePicker(_, def):              v.strings[f.key] = def
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
