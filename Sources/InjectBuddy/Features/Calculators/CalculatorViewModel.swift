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

    @Published var values: CalculatorValues { didSet { recompute() } }
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
        self.values = CalculatorValues.defaults(for: spec.fields)
        recompute()
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
            case .stringPicker:
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

    private static func todayString() -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
