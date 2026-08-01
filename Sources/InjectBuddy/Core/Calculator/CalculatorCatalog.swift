import Foundation

// ─── CalculatorCatalog ───────────────────────────────────────────────────────
// Declarative field configuration for every calculator slug, plus the exact
// `saved_dosages.calculator_type` string the web writes (`savedType`). The generic
// CalculatorScreen + CalculatorViewModel read these specs; they never hard-code
// fields. Option arrays mirror app.js constants verbatim.

// MARK: - Shared option constants (verbatim from app.js)

enum CalcConst {
    static let esterTypes = [
        "Testosterone Cypionate", "Testosterone Enanthate", "Testosterone Propionate",
        "Testosterone Undecanoate", "Testosterone Acetate", "Testosterone Suspension",
        "Sustanon 250",
    ]
    // SEMA_DOSE_VALUES / TIRZ_DOSE_VALUES / RETA_DOSE_VALUES
    static let semaDoses: [Double] = [0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.4]
    static let tirzDoses: [Double] = [0, 2.5, 5, 7.5, 10, 12.5, 15]
    static let retaDoses: [Double] = [0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
    static let glp1Concs: [Double] = [0, 1, 2, 2.5, 3, 4, 5, 7.5, 10, 12.5, 15, 20]

    static func doseOptions(_ values: [Double]) -> [CalculatorInput.PickerOption] {
        values.map { v in
            CalculatorInput.PickerOption(label: v == v.rounded() ? String(Int(v)) : String(v), value: v)
        }
    }
}

// MARK: - Plotter compound list (verbatim from app.js PLOTTER_COMPOUNDS)

struct PlotterCompound: Identifiable, Equatable {
    let id: String
    let label: String
    let category: String
    let halfLife: Double  // days
    let tmax: Double      // days
    let defaultDose: Double
    let unit: String      // "mg" or "mcg"

    static let all: [PlotterCompound] = [
        .init(id: "test-e", label: "Testosterone Enanthate", category: "Testosterone", halfLife: 4.5, tmax: 2.0, defaultDose: 100, unit: "mg"),
        .init(id: "test-c", label: "Testosterone Cypionate", category: "Testosterone", halfLife: 5.0, tmax: 2.5, defaultDose: 100, unit: "mg"),
        .init(id: "test-p", label: "Testosterone Propionate", category: "Testosterone", halfLife: 0.8, tmax: 0.5, defaultDose: 50, unit: "mg"),
        .init(id: "test-u", label: "Testosterone Undecanoate", category: "Testosterone", halfLife: 20.0, tmax: 6.0, defaultDose: 1000, unit: "mg"),
        .init(id: "npp", label: "Nandrolone Phenylpropionate (NPP)", category: "AAS", halfLife: 2.5, tmax: 1.0, defaultDose: 100, unit: "mg"),
        .init(id: "deca", label: "Nandrolone Decanoate (Deca)", category: "AAS", halfLife: 7.0, tmax: 3.0, defaultDose: 200, unit: "mg"),
        .init(id: "tren-a", label: "Trenbolone Acetate", category: "AAS", halfLife: 1.5, tmax: 0.5, defaultDose: 100, unit: "mg"),
        .init(id: "tren-e", label: "Trenbolone Enanthate", category: "AAS", halfLife: 5.5, tmax: 2.0, defaultDose: 200, unit: "mg"),
        .init(id: "eq", label: "Boldenone Undecylenate (EQ)", category: "AAS", halfLife: 14.0, tmax: 5.0, defaultDose: 300, unit: "mg"),
        .init(id: "mast-p", label: "Drostanolone Propionate (Mast-P)", category: "AAS", halfLife: 2.5, tmax: 0.8, defaultDose: 100, unit: "mg"),
        .init(id: "mast-e", label: "Drostanolone Enanthate (Mast-E)", category: "AAS", halfLife: 5.5, tmax: 2.0, defaultDose: 200, unit: "mg"),
        .init(id: "bpc157", label: "BPC-157", category: "Peptide", halfLife: 0.17, tmax: 0.04, defaultDose: 250, unit: "mcg"),
        .init(id: "tb500", label: "TB-500 (Thymosin β-4)", category: "Peptide", halfLife: 0.58, tmax: 0.25, defaultDose: 2000, unit: "mcg"),
        .init(id: "cjc-nodac", label: "CJC-1295 (no DAC)", category: "Peptide", halfLife: 0.021, tmax: 0.010, defaultDose: 100, unit: "mcg"),
        .init(id: "cjc-dac", label: "CJC-1295 + DAC", category: "Peptide", halfLife: 8.0, tmax: 2.0, defaultDose: 2000, unit: "mcg"),
        .init(id: "ipamorelin", label: "Ipamorelin", category: "Peptide", halfLife: 0.083, tmax: 0.042, defaultDose: 200, unit: "mcg"),
        .init(id: "ghrp2", label: "GHRP-2", category: "Peptide", halfLife: 0.083, tmax: 0.021, defaultDose: 200, unit: "mcg"),
        .init(id: "ghrp6", label: "GHRP-6", category: "Peptide", halfLife: 0.083, tmax: 0.021, defaultDose: 200, unit: "mcg"),
        .init(id: "sermorelin", label: "Sermorelin", category: "Peptide", halfLife: 0.0076, tmax: 0.003, defaultDose: 300, unit: "mcg"),
        .init(id: "hgh", label: "HGH (Somatropin)", category: "Peptide", halfLife: 0.158, tmax: 0.125, defaultDose: 1000, unit: "mcg"),
        .init(id: "pt141", label: "PT-141", category: "Peptide", halfLife: 0.113, tmax: 0.042, defaultDose: 1000, unit: "mcg"),
        .init(id: "igf1lr3", label: "IGF-1 LR3", category: "Peptide", halfLife: 0.83, tmax: 0.25, defaultDose: 100, unit: "mcg"),
        .init(id: "ta1", label: "Thymosin Alpha-1", category: "Peptide", halfLife: 0.083, tmax: 0.021, defaultDose: 1000, unit: "mcg"),
        .init(id: "mt2", label: "Melanotan II", category: "Peptide", halfLife: 3.7, tmax: 0.042, defaultDose: 500, unit: "mcg"),
        .init(id: "sema", label: "Semaglutide", category: "GLP-1", halfLife: 7.0, tmax: 1.0, defaultDose: 0.5, unit: "mg"),
        .init(id: "tirz", label: "Tirzepatide", category: "GLP-1", halfLife: 5.0, tmax: 1.0, defaultDose: 2.5, unit: "mg"),
        .init(id: "reta", label: "Retatrutide", category: "GLP-1", halfLife: 7.0, tmax: 1.0, defaultDose: 1.0, unit: "mg"),
    ]

    /// PLOTTER_FREQS — labeled dosing intervals in days.
    static let freqs: [CalculatorInput.PickerOption] = [
        .init(label: "Three times/day (TID)", value: 0.33),
        .init(label: "Twice per day (BID)", value: 0.5),
        .init(label: "Every day (ED)", value: 1),
        .init(label: "Every other day (EOD)", value: 2),
        .init(label: "Every 3 days", value: 3),
        .init(label: "Twice per week (2x/wk)", value: 3.5),
        .init(label: "Once per week", value: 7),
        .init(label: "Every 2 weeks (E2W)", value: 14),
    ]
}

// MARK: - Spec

struct CalculatorSpec: Equatable {
    let slug: CalculatorSlug
    /// The exact `saved_dosages.calculator_type` the web writes.
    let savedType: String
    /// Human label seed for the saved-protocol title.
    let saveTitle: String
    let fields: [CalculatorInput]

    static func == (l: CalculatorSpec, r: CalculatorSpec) -> Bool { l.slug == r.slug }
}

enum CalculatorCatalog {

    // Frequency picker shared by TRT-style calculators (Daily..1×, value = inj/week).
    private static let trtFreqOptions: [CalculatorInput.PickerOption] = [
        .init(label: "Daily", value: 7),
        .init(label: "EOD", value: 3.5),
        .init(label: "3×/week", value: 3),
        .init(label: "2×/week", value: 2),
        .init(label: "1×/week", value: 1),
    ]

    // MARK: - Syringe barrel
    //
    // `syringeMl` was already written to saved_dosages.config by configExtras and
    // already read by the web (lib/account-schedule.ts), but the phone had no
    // control for it — the gap this file's note below calls out by name.
    //
    // CRITICAL: a slug that renders this picker must NOT also list syringeMl in
    // configExtras. configJSON() applies extras AFTER field values and lets them
    // win, so a leftover extra silently overwrites the user's choice — and because
    // the unique index covers the WHOLE config, a wrong value makes an iOS save a
    // DIFFERENT protocol from the equivalent web row rather than the same one.
    static let barrelOptions: [CalculatorInput.PickerOption] = [
        .init(label: "0.3 mL (30u)", value: 0.3),
        .init(label: "0.5 mL (50u)", value: 0.5),
        .init(label: "1 mL (100u)", value: 1),
        .init(label: "3 mL (IM)", value: 3),
    ]

    /// The value configExtras used to hardcode for this slug. Used as the picker's
    /// initial value so a user who never touches the control saves exactly what
    /// the previous build saved, and the fingerprint is unchanged.
    static func defaultBarrel(for slug: CalculatorSlug) -> Double {
        switch slug {
        case .eod, .microdose: return 0.3
        case .hcg: return 0.5
        default: return 1
        }
    }

    static func barrelField(for slug: CalculatorSlug) -> CalculatorInput {
        .picker("syringeMl", "Syringe barrel",
                options: barrelOptions, default: defaultBarrel(for: slug))
    }

    // MARK: - Cross-platform config shape
    //
    // saved_dosages.config must be BYTE-EQUIVALENT to what the web writes for the same
    // protocol. Two things depend on it:
    //   1. The web reads a protocol back into its calculator by key. A missing `mode`
    //      or `nDays` means it cannot restore what was saved on the phone.
    //   2. The database de-duplicates on the WHOLE config — a unique index on
    //      (user_id, calculator_type, config), config stored as jsonb so key order
    //      and 1-vs-1.0 normalise on storage. A config missing keys is a DIFFERENT
    //      row from the equivalent web one, so the same protocol saved on both
    //      platforms exists twice instead of resolving to a single id.
    //      iOS does NOT go through the web's /api/dosages: that route is
    //      cookie-authenticated and unreachable from the app. Writes are direct
    //      PostgREST inserts, and the index is what makes both platforms agree.
    //
    // The generic spec model only knows the fields it renders, and the web saves state
    // the phone has no control for — barrel size, the dosing mode, the unused half of a
    // mode pair. These two functions close that gap: `configOmittedKeys` drops iOS-only
    // field keys, `configExtras` supplies the rest.
    //
    // Values are the web's own defaults for anything iOS does not model, taken from the
    // corresponding page's useState in public/app.js. That is deliberate: it makes an
    // iOS save identical to an untouched web save with the same inputs, which is exactly
    // what the fingerprint needs. Where iOS DOES know the answer — the dosing mode it
    // actually evaluated — the real value is written, not a default.

    /// Field keys that exist for the iOS UI but are not part of the web's config.
    static func configOmittedKeys(for slug: CalculatorSlug) -> Set<String> {
        switch slug {
        // The picker stores a Double; the web's `doseUnit` is the string 'mcg'/'mg'.
        // Emitted with the right name and type by configExtras below.
        case .peptide: return ["doseUnitMcg"]
        // An index into SteroidCatalog — an iOS implementation detail. The web keys
        // the compound by its slug string.
        case .steroid: return ["compound"]
        default: return []
        }
    }

    /// Keys the web writes that the iOS form has no field for.
    static func configExtras(for slug: CalculatorSlug, values v: CalculatorValues) -> [String: JSONValue] {
        switch slug {
        case .trt:
            // evaluate() runs TRT in perweek mode, so that is the honest value here.
            // nDays/mlDrawn are the unused half of the mode pair; web defaults.
            // syringeMl is a real field now — see barrelField. Emitting it here too
            // would overwrite the user's choice (extras win in configJSON).
            return ["mode": .string("perweek"), "nDays": .number(3.5),
                    "mlDrawn": .number(0.5)]

        case .eod:
            // Web's EOD lives on the MicrodoseTRT page, whose barrel default is 0.3 —
            // now carried by barrelField's default rather than hardcoded here.
            return [:]

        case .microdose:
            return ["mode": .string("ndays"), "injPerWeek": .number(0),
                    "mlDrawn": .number(0.5), "esterType": .string("")]

        case .hcg:
            return ["mode": .string("perweek"),
                    "nDays": .number(3.5), "injPerWeek": .number(2)]

        case .semaglutide, .tirzepatide, .retatrutide:
            return ["mode": .string("perweek"),
                    "nDays": .number(7), "injPerWeek": .number(1)]

        case .peptide:
            // peptideType has no iOS field yet, so "" is the truthful answer: nothing
            // was chosen. Add the picker and this becomes a real value (TASK 16/17).
            return ["doseUnit": .string(v.number("doseUnitMcg") == 1 ? "mcg" : "mg"),
                    "peptideType": .string("")]

        case .reconstitution:
            return ["pepUnit": .string("mg")]

        case .bpc157, .bpc157blend:
            return [:]

        case .steroid:
            let idx = Int(v.number("compound"))
            let compound = SteroidCatalog.all.indices.contains(idx)
                ? SteroidCatalog.all[idx] : SteroidCatalog.all[0]
            // Injectable-only for now (see the spec below), so form/mode are known.
            // The oral trio (dose/tab/split) are the web's own empty defaults.
            return ["slug": .string(compound.key),
                    "form": .string("injectable"),
                    "mode": .string("ndays"),
                    "esterKey": .string(compound.defaultEster?.key ?? ""),
                    "injPerWeek": .number(2),
                    "mlDrawn": .number(0.5),
                    "dose": .string(""),
                    "tab": .string(""),
                    "split": .string("1")]

        case .bmi, .freeTestIndex, .cyclePlotter:
            // Never saved — canSaveProtocol is false.
            return [:]
        }
    }

    static func spec(for slug: CalculatorSlug) -> CalculatorSpec {
        switch slug {

        case .trt:
            // config keys mirror web: strength, mgWeek, injPerWeek, mode, esterType.
            return CalculatorSpec(slug: slug, savedType: "trt", saveTitle: "TRT Dose", fields: [
                .number("strength", "Vial strength", unit: "mg/mL", default: 200, range: 1...500, step: 1),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 100, range: 0...1000, step: 1),
                .picker("injPerWeek", "Frequency", options: trtFreqOptions, default: 2),
                .stringPicker("esterType", "Ester", options: CalcConst.esterTypes, default: "Testosterone Enanthate"),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .eod:
            return CalculatorSpec(slug: slug, savedType: "eod", saveTitle: "TRT & EOD", fields: [
                .number("strength", "Vial strength", unit: "mg/mL", default: 200, range: 1...500, step: 1),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 70, range: 0...1000, step: 1,
                        help: "Hardcoded every-other-day interval (3.5 injections/week)."),
                .stringPicker("esterType", "Ester", options: CalcConst.esterTypes, default: "Testosterone Enanthate"),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .microdose:
            // micro defaults to small strength + every-N-days mode.
            return CalculatorSpec(slug: slug, savedType: "microdose", saveTitle: "TRT Microdose", fields: [
                .number("strength", "Vial strength", unit: "mg/mL", default: 10, range: 1...100, step: 1),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 5, range: 0...100, step: 0.5),
                .number("nDays", "Inject every", unit: "days", default: 3, range: 1...7, step: 1),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .hcg:
            return CalculatorSpec(slug: slug, savedType: "hcg", saveTitle: "HCG", fields: [
                .number("vialIU", "Vial size", unit: "IU", default: 5000, range: 0...20000, step: 100),
                .number("bacWaterMl", "Bac water", unit: "mL", default: 1, range: 0...10, step: 0.5),
                .number("dose", "Dose per injection", unit: "IU", default: 250, range: 0...5000, step: 50),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .peptide:
            return CalculatorSpec(slug: slug, savedType: "peptide", saveTitle: "Peptide", fields: [
                .number("peptideMg", "Peptide in vial", unit: "mg", default: 50, range: 0...100, step: 1),
                .number("bawMl", "Bac water", unit: "mL", default: 10, range: 0...30, step: 0.5),
                .number("dosePerInj", "Dose per injection", default: 500, range: 0...10000, step: 50),
                .picker("doseUnitMcg", "Dose unit", options: [
                    .init(label: "mcg", value: 1), .init(label: "mg", value: 0),
                ], default: 1),
                .number("injPerWeek", "Injections/week", unit: "×", default: 1, range: 1...14, step: 1),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .reconstitution:
            return CalculatorSpec(slug: slug, savedType: "reconstitution", saveTitle: "Reconstitution", fields: [
                .number("peptideMg", "Peptide in vial", unit: "mg", default: 5, range: 0...100, step: 1),
                .number("targetConc", "Target concentration", unit: "mcg/mL", default: 1000, range: 0...10000, step: 50),
            ])

        case .semaglutide:
            return CalculatorSpec(slug: slug, savedType: "semaglutide", saveTitle: "Semaglutide", fields: [
                .picker("conc", "Concentration", options: CalcConst.doseOptions(CalcConst.glp1Concs), default: 5,
                        help: "mg/mL after reconstitution."),
                .picker("dose", "Dose", options: CalcConst.doseOptions(CalcConst.semaDoses), default: 0.5,
                        help: "mg per weekly injection."),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .tirzepatide:
            return CalculatorSpec(slug: slug, savedType: "tirzepatide", saveTitle: "Tirzepatide", fields: [
                .picker("conc", "Concentration", options: CalcConst.doseOptions(CalcConst.glp1Concs), default: 7.5,
                        help: "mg/mL after reconstitution."),
                .picker("dose", "Dose", options: CalcConst.doseOptions(CalcConst.tirzDoses), default: 5,
                        help: "mg per weekly injection."),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .retatrutide:
            return CalculatorSpec(slug: slug, savedType: "retatrutide", saveTitle: "Retatrutide", fields: [
                .picker("conc", "Concentration", options: CalcConst.doseOptions(CalcConst.glp1Concs), default: 5,
                        help: "mg/mL after reconstitution."),
                .picker("dose", "Dose", options: CalcConst.doseOptions(CalcConst.retaDoses), default: 1,
                        help: "mg per weekly injection."),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .bpc157:
            // Vial + water rather than a pre-computed concentration, matching the web.
            // This was the one calculator whose INPUT MODEL differed, not just its key
            // names: the web saves {vialMg, bawMl, dose, syringeMl} and a concentration
            // cannot be split back into a vial size and a water volume, so no amount of
            // key mapping could have reconciled it. The engine is untouched — evaluate
            // derives mcg/mL from these two before calling it.
            return CalculatorSpec(slug: slug, savedType: "bpc157", saveTitle: "BPC-157", fields: [
                .number("vialMg", "Vial size", unit: "mg", default: 5, range: 0...100, step: 1),
                .number("bawMl", "Bac water", unit: "mL", default: 2, range: 0...30, step: 0.5),
                .number("dose", "Dose per injection", unit: "mcg", default: 250, range: 0...5000, step: 50),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .bpc157blend:
            return CalculatorSpec(slug: slug, savedType: "bpc157blend", saveTitle: "BPC+TB500", fields: [
                .number("bpcVial", "BPC-157 in vial", unit: "mcg", default: 5000, range: 0...20000, step: 250),
                .number("bpcWater", "BPC-157 bac water", unit: "mL", default: 2, range: 0...10, step: 0.5),
                .number("bpcDose", "BPC-157 dose", unit: "mcg", default: 250, range: 0...5000, step: 50),
                .number("tbVial", "TB-500 in vial", unit: "mcg", default: 5000, range: 0...20000, step: 250),
                .number("tbWater", "TB-500 bac water", unit: "mL", default: 2, range: 0...10, step: 0.5),
                .number("tbDose", "TB-500 dose", unit: "mcg", default: 2000, range: 0...5000, step: 50),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .bmi:
            // unitsImperial toggle: off = metric, on = imperial.
            return CalculatorSpec(slug: slug, savedType: "bmi", saveTitle: "BMI", fields: [
                .toggle("imperial", "Imperial units", default: false),
                .number("heightCm", "Height", unit: "cm", default: 180, range: 0...260, step: 1),
                .number("weightKg", "Weight", unit: "kg", default: 80, range: 0...300, step: 0.5),
                .number("heightFt", "Height (ft)", unit: "ft", default: 5, range: 0...8, step: 1),
                .number("heightIn", "Height (in)", unit: "in", default: 10, range: 0...11, step: 1),
                .number("weightLb", "Weight", unit: "lb", default: 180, range: 0...660, step: 1),
            ])

        case .freeTestIndex:
            return CalculatorSpec(slug: slug, savedType: "freetest", saveTitle: "Free T Index", fields: [
                .number("tt", "Total testosterone", default: 20, range: 0...2000, step: 0.1),
                .picker("ttUnitNgdl", "TT unit", options: [
                    .init(label: "nmol/L", value: 0), .init(label: "ng/dL", value: 1),
                ], default: 0),
                .number("shbg", "SHBG", unit: "nmol/L", default: 50, range: 0...250, step: 1),
            ])

        case .cyclePlotter:
            // Bespoke screen — no generic fields.
            return CalculatorSpec(slug: slug, savedType: "plotter", saveTitle: "Cycle Plotter", fields: [])

        case .steroid:
            // Injectable path only, for now. The web screen also has an ORAL form
            // (mg/day ÷ split → tablets) for the seven oral compounds, and the engine
            // side of that is ported — CalculatorEngine.steroidOral — but the generic
            // field/spec model here renders ONE set of inputs, and the web swaps the
            // whole input set on a form toggle. Wiring that needs a bespoke screen
            // rather than a spec, so orals are held back rather than shipped showing
            // syringe fields that mean nothing for a tablet.
            //
            // `compound` is an index into SteroidCatalog.all rather than a string,
            // because the generic picker field carries a Double. The screen resolves
            // it back to a compound, and configJSON writes the index — which is why
            // the saved config here will NOT yet match the web's shape (see below).
            return CalculatorSpec(slug: slug, savedType: "steroid", saveTitle: "Steroid Dosage", fields: [
                .picker("compound", "Compound",
                        options: SteroidCatalog.all.enumerated().map { idx, c in
                            .init(label: c.displayName, value: Double(idx))
                        },
                        default: 0),
                .number("strength", "Vial strength", unit: "mg/mL", default: 200, range: 0...500, step: 5),
                .number("mgWeek", "Weekly dose", unit: "mg", default: 300, range: 0...2000, step: 5),
                .number("nDays", "Inject every", unit: "days", default: 3.5, range: 0.5...14, step: 0.5),
                .picker("syringeMl", "Syringe barrel",
                        options: barrelOptions, default: defaultBarrel(for: slug)),
            ])
        }
    }
}
