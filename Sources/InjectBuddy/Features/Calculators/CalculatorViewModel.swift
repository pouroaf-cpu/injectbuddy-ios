import Foundation
import SwiftUI

// ─── CalculatorViewModel ─────────────────────────────────────────────────────
// Holds the live input bag for one calculator, recomputes its CalculatorResult
// on every change, and saves the inputs as a protocol via the backend. The view
// binds directly to `values`; `result` is republished whenever inputs (or the
// syringe scale) change.

@MainActor
final class CalculatorViewModel: ObservableObject {
    let spec: CalculatorSpec

    @Published var values: CalculatorValues { didSet { valuesChanged(from: oldValue) } }
    @Published private(set) var result: CalculatorResult = .empty
    @Published var saveState: SaveState = .idle
    /// Row id from the last successful save, for the confirm-start-day step.
    @Published var savedId: String?

    /// Syringe scale supplied by the screen from SettingsStore; affects TRT units.
    var scale: SyringeScale = .u100 { didSet { if scale != oldValue { recompute() } } }

    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }

    init(slug: CalculatorSlug) {
        let spec = CalculatorCatalog.spec(for: slug)
        self.spec = spec
        var seed = CalculatorValues.defaults(for: spec.fields)
        // T-96 — the steroid strengths belong to the COMPOUND, so the form opens on
        // the opening compound's, not on the spec's. The web seeds them at mount:
        // `useState(defConc)` / `useState(String(defTab))` (`app.js:8803`, `8811`).
        //
        // TODAY THIS IS THE IDENTITY, and that is the point of doing it rather than
        // trusting it: the form opens on `picks[0]`, Oxandrolone, whose defaults ARE
        // the spec's 200 mg/mL and 10 mg/tab. If the picker order ever moves to the
        // web's (`IB_STEROID_ORDER`, `app.js:8762`, starting at Trenbolone) the
        // opening strengths follow it instead of silently staying behind. Assigning
        // in `init` does not fire `didSet`, so nothing recomputes twice.
        if spec.slug == .steroid {
            seed = SteroidCatalog.seeding(seed, forPickAt: Int(seed.number("compound")),
                                          includingTablet: true)
        }
        self.values = seed
        recompute()
    }

    /// The spec's fields IN THE UNITS CURRENTLY SELECTED — what the screen renders.
    ///
    /// `spec.fields` is still the canonical key set and is what `configJSON()` walks;
    /// this is the display resolution of it, and it is a computed property rather than
    /// stored state so it cannot fall out of step with `values`. Identity for the
    /// fourteen calculators with no unit-scaled field.
    var fields: [CalculatorInput] { spec.resolvedFields(values) }

    /// T-41 — the ONE place a change to `values` writes `values` back.
    ///
    /// The spec resolution above is pure and happens on every render; a conversion or a
    /// seed is a TRANSITION and must happen exactly once, which is why both live on the
    /// `didSet` edge where the old and new bags are both in hand rather than in a view.
    ///
    /// RE-ENTRANCY IS REAL AND IS HANDLED, not hoped about: writing `values` here fires
    /// this same `didSet` again. `isSettling` (T-41's `isConverting`, now covering the
    /// T-96 seed too) makes the second pass do the recompute and nothing else, so the
    /// bag settles in one step and the engine is evaluated once, against the settled
    /// numbers.
    private var isSettling = false

    private func valuesChanged(from old: CalculatorValues) {
        if !isSettling, let settled = settling(from: old) {
            isSettling = true
            values = settled
            isSettling = false
            return  // the re-entrant pass above already recomputed, on the right values
        }
        recompute()
    }

    /// The bag as it must be AFTER a transition the user just made, or nil when the
    /// change was an ordinary edit — which is nearly every change, and the reason both
    /// rules take `old` as well as `new` rather than reading the current bag alone.
    ///
    /// THE SLUG BRANCH IS DELIBERATE AND IS NOT THE END STATE. T-41 rejected
    /// `if slug == .peptide` in `CalculatorScreen` because the screen renders fifteen
    /// calculators from their specs and must not know about any of them; the same
    /// argument says a seeder should be DECLARED on the spec, the way `UnitScaling` is,
    /// and dispatched here without naming a calculator. That declaration belongs in
    /// `CalculatorModels`/`CalculatorCatalog` and is T-47's sweep, not this task's — so
    /// the RULE lives in `SteroidCatalog` where a unit test can reach it, and this is
    /// the single line that calls it.
    private func settling(from old: CalculatorValues) -> CalculatorValues? {
        if let converted = spec.convertingUnits(from: old, to: values) { return converted }
        if spec.slug == .steroid { return SteroidCatalog.reseeding(from: old, to: values) }
        return nil
    }

    private func recompute() {
        result = CalculatorEngine.evaluate(slug: spec.slug, values: values, scale: scale)
    }

    /// Bindings the generic form uses.
    func numberBinding(_ key: String) -> Binding<Double> {
        Binding(get: { self.values.numbers[key] ?? 0 },
                set: { self.values.numbers[key] = $0 })
    }
    func stringBinding(_ key: String) -> Binding<String> {
        Binding(get: { self.values.strings[key] ?? "" },
                set: { self.values.strings[key] = $0 })
    }
    func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { self.values.bools[key] ?? false },
                set: { self.values.bools[key] = $0 })
    }

    /// Builds the config JSON from current inputs and saves a protocol.
    func save(backend: BackendClient) async {
        guard result.isValid else {
            saveState = .failed("Enter valid values first")
            return
        }
        saveState = .saving
        let body = NewSavedDosage(
            calculatorType: spec.savedType,
            label: spec.saveTitle,
            config: configJSON(),
            startDate: Self.todayString()
        )
        do {
            // Keep the new id: the screen hands it to the confirm-start-day step, which
            // reads the row back and lets the start day be corrected off today's default.
            savedId = try await backend.saveDosage(body)
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }

    /// Encode the current field values into the config shape the web writes to
    /// saved_dosages.config.
    ///
    /// The rendered fields alone are NOT that shape — the web saves state this form has
    /// no control for (barrel size, dosing mode, the unused half of a mode pair), and a
    /// couple of iOS field keys are internal. So the field values are filtered through
    /// configOmittedKeys and then completed by configExtras; see the long note on both
    /// in CalculatorCatalog. Getting this wrong does not just look untidy: the web
    /// restores a protocol by key, and the database de-duplicates on the WHOLE config
    /// via a unique index on (user_id, calculator_type, config), so a config that differs
    /// by even one key is a different protocol rather than the same one.
    func configJSON() -> JSONValue {
        var obj: [String: JSONValue] = [:]
        let omitted = CalculatorCatalog.configOmittedKeys(for: spec.slug)
        for field in spec.fields where !omitted.contains(field.key) {
            switch field.kind {
            case .number, .picker, .segmented, .stepperDays:
                obj[field.key] = .number(values.number(field.key))
            case .stringPicker, .modePicker:
                obj[field.key] = .string(values.string(field.key))
            case .toggle:
                obj[field.key] = .bool(values.bool(field.key))
            }
        }
        // Extras win: where a key is both a field and an extra, the extra is the one
        // carrying the web's name and type.
        for (key, value) in CalculatorCatalog.configExtras(for: spec.slug, values: values) {
            obj[key] = value
        }
        return .object(obj)
    }

    /// Today, as the person holding the phone would name it — the seed for
    /// `start_date`, which BOTH projection engines derive every dose day from.
    ///
    /// **T-82.** This was a private `DateFormatter`, and it was already in the right
    /// frame (`TimeZone.current`) — but it was one of four private copies of the same
    /// conversion, and the web demonstrated on 2026-08-04 what that costs: it had six,
    /// two of them reached for `toISOString`, and one of those two seeded exactly this
    /// field, shifting a real Auckland user's whole schedule by a day. There is now one
    /// named writer and this calls it.
    private static func todayString() -> String {
        dpLocalDay(Date())
    }
}
