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
    let fields: [CalculatorInput]
    /// Human label seed for the saved-protocol title.
    let saveTitle: String

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

    static func spec(for slug: CalculatorSlug) -> CalculatorSpec {
        switch slug {

        case .trt:
            // config keys mirror web: strength, mgWeek, injPerWeek, mode, esterType.
            return CalculatorSpec(slug: slug, savedType: "trt", saveTitle: "TRT Dose", fields: [
                .number("strength", "Vial strength", unit: "mg/mL", default: 200, range: 1...500, step: 1),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 100, range: 0...1000, step: 1),
                .picker("injPerWeek", "Frequency", options: trtFreqOptions, default: 2),
                .stringPicker("esterType", "Ester", options: CalcConst.esterTypes, default: "Testosterone Enanthate"),
            ])

        case .eod:
            return CalculatorSpec(slug: slug, savedType: "eod", saveTitle: "TRT & EOD", fields: [
                .number("strength", "Vial strength", unit: "mg/mL", default: 200, range: 1...500, step: 1),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 70, range: 0...1000, step: 1,
                        help: "Hardcoded every-other-day interval (3.5 injections/week)."),
                .stringPicker("esterType", "Ester", options: CalcConst.esterTypes, default: "Testosterone Enanthate"),
            ])

        case .microdose:
            // micro defaults to small strength + every-N-days mode.
            return CalculatorSpec(slug: slug, savedType: "microdose", saveTitle: "TRT Microdose", fields: [
                .number("strength", "Vial strength", unit: "mg/mL", default: 10, range: 1...100, step: 1),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 5, range: 0...100, step: 0.5),
                .number("nDays", "Inject every", unit: "days", default: 3, range: 1...7, step: 1),
            ])

        case .hcg:
            return CalculatorSpec(slug: slug, savedType: "hcg", saveTitle: "HCG", fields: [
                .number("vialIU", "Vial size", unit: "IU", default: 5000, range: 0...20000, step: 100),
                .number("bacWaterMl", "Bac water", unit: "mL", default: 1, range: 0...10, step: 0.5),
                .number("dose", "Dose per injection", unit: "IU", default: 250, range: 0...5000, step: 50),
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
            ])

        case .tirzepatide:
            return CalculatorSpec(slug: slug, savedType: "tirzepatide", saveTitle: "Tirzepatide", fields: [
                .picker("conc", "Concentration", options: CalcConst.doseOptions(CalcConst.glp1Concs), default: 7.5,
                        help: "mg/mL after reconstitution."),
                .picker("dose", "Dose", options: CalcConst.doseOptions(CalcConst.tirzDoses), default: 5,
                        help: "mg per weekly injection."),
            ])

        case .retatrutide:
            return CalculatorSpec(slug: slug, savedType: "retatrutide", saveTitle: "Retatrutide", fields: [
                .picker("conc", "Concentration", options: CalcConst.doseOptions(CalcConst.glp1Concs), default: 5,
                        help: "mg/mL after reconstitution."),
                .picker("dose", "Dose", options: CalcConst.doseOptions(CalcConst.retaDoses), default: 1,
                        help: "mg per weekly injection."),
            ])

        case .bpc157:
            return CalculatorSpec(slug: slug, savedType: "bpc157", saveTitle: "BPC-157", fields: [
                .number("concMcgMl", "Concentration", unit: "mcg/mL", default: 2500, range: 0...20000, step: 100),
                .number("dose", "Dose per injection", unit: "mcg", default: 250, range: 0...5000, step: 50),
            ])

        case .bpc157blend:
            return CalculatorSpec(slug: slug, savedType: "bpc157blend", saveTitle: "BPC+TB500", fields: [
                .number("bpcVial", "BPC-157 in vial", unit: "mcg", default: 5000, range: 0...20000, step: 250),
                .number("bpcWater", "BPC-157 bac water", unit: "mL", default: 2, range: 0...10, step: 0.5),
                .number("bpcDose", "BPC-157 dose", unit: "mcg", default: 250, range: 0...5000, step: 50),
                .number("tbVial", "TB-500 in vial", unit: "mcg", default: 5000, range: 0...20000, step: 250),
                .number("tbWater", "TB-500 bac water", unit: "mL", default: 2, range: 0...10, step: 0.5),
                .number("tbDose", "TB-500 dose", unit: "mcg", default: 2000, range: 0...5000, step: 50),
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
        }
    }
}
