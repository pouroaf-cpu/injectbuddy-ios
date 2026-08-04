import Foundation

// ─── CalculatorEngine.evaluate ───────────────────────────────────────────────
// Bridges the UI value-bag (CalculatorValues) to the typed engine functions and
// formats a CalculatorResult for display. Still pure Swift (no SwiftUI). The
// formatting helpers live here so the engine file stays formula-only.

extension CalculatorEngine {

    /// Format a Double with `n` decimals, trimming behaviour matching the web's fmt.
    static func fmt(_ v: Double, _ decimals: Int = 2) -> String {
        guard v.isFinite else { return "—" }
        return String(format: "%.\(decimals)f", v)
    }

    /// Whole-number formatting for unit counts (web uses Math.round for unit displays).
    static func fmtInt(_ v: Double) -> String {
        guard v.isFinite else { return "—" }
        return String(Int(v.rounded()))
    }

    /// Generic UI entry point. `scale` only affects calculators where the web
    /// surfaces U-100/U-40 syringe scaling (the TRT family); GLP-1/peptide/bpc
    /// stay on the ×100 convention exactly as the JS does.
    static func evaluate(slug: CalculatorSlug, values v: CalculatorValues,
                         scale: SyringeScale) -> CalculatorResult {
        switch slug {

        case .trt:
            // T-01a #1. `mode` was `.perweek`, hardcoded, with `nDays` and `mlDrawn`
            // passed as 0 — so two of the engine's three branches were unreachable
            // from the phone even though the engine has always had all three and
            // every saved config carried a `mode` key.
            //
            // Falls back to the web's own default rather than to the old hardcoded
            // value: an unrecognised or missing string means "this row predates the
            // field", and `ndays` is what `app.js:8246` opens on.
            let mode = CalculatorEngine.TrtMode(rawValue: v.string("mode")) ?? .ndays
            let r = trt(strength: v.number("strength"), mgWeek: v.number("mgWeek"),
                        mode: mode, nDays: v.number("nDays"),
                        injPerWeek: v.number("injPerWeek"),
                        mlDrawn: v.number("mlDrawn"), unitsPerML: scale.unitsPerML)
            return trtResult(r, scale: scale)

        case .eod:
            let r = eod(strength: v.number("strength"), mgWeek: v.number("mgWeek"),
                        unitsPerML: scale.unitsPerML)
            return trtResult(r, scale: scale)

        case .microdose:
            let r = trt(strength: v.number("strength"), mgWeek: v.number("mgWeek"),
                        mode: .ndays, nDays: v.number("nDays"), injPerWeek: 0,
                        mlDrawn: 0, unitsPerML: scale.unitsPerML)
            return trtResult(r, scale: scale)

        case .hcg:
            let r = hcg(vialIU: v.number("vialIU"), bacWaterMl: v.number("bacWaterMl"),
                        dose: v.number("dose"))
            return CalculatorResult(rows: [
                ResultRow(label: "Draw", value: "\(fmt(r.drawMl, 3)) mL", emphasis: true),
                ResultRow(label: "Units (U-100)", value: fmtInt(r.units), emphasis: true),
                ResultRow(label: "Concentration", value: "\(fmt(r.concentration, 0)) IU/mL"),
                ResultRow(label: "Doses per vial", value: fmtInt(r.dosesPerVial)),
            ], isValid: r.isValid, scheduleLine: r.isValid ? volumeMeta(r.drawMl) : nil, drawMl: r.drawMl)

        case .peptide:
            let r = peptide(peptideMg: v.number("peptideMg"), bawMl: v.number("bawMl"),
                            dosePerInj: v.number("dosePerInj"),
                            doseUnit: v.number("doseUnitMcg") == 1 ? "mcg" : "mg",
                            injPerWeek: v.number("injPerWeek"))
            return CalculatorResult(rows: [
                ResultRow(label: "Draw per injection", value: "\(fmt(r.mlPerInj, 3)) mL", emphasis: true),
                ResultRow(label: "Units (U-100)", value: fmtInt(r.unitsPerInj), emphasis: true),
                ResultRow(label: "Concentration", value: "\(fmt(r.concentration, 2)) mg/mL"),
                ResultRow(label: "Weekly total", value: "\(fmt(r.weeklyTotalMg, 3)) mg"),
                ResultRow(label: "Total doses in vial", value: fmt(r.totalDoses, 1)),
            ], isValid: r.isValid,
               scheduleLine: r.isValid ? "Vial lasts ~\(fmt(r.vialWeeks, 1)) weeks" : nil,
               // `drawMl` was the ONE injectable branch that did not carry it, while its
               // own first row renders `Draw per injection`. Structured `drawMl` has two
               // consumers and peptide was silently absent from both: the barrel
               // over-capacity check (`ResultCard.overCapacity`) never fired on this
               // calculator, and `DoseVolume.perInjectionMl` had no volume to log.
               // Same omission, two symptoms — the one-of-N-sites shape again.
               drawMl: r.mlPerInj)

        case .reconstitution:
            let r = reconstitution(peptideMg: v.number("peptideMg"), targetConc: v.number("targetConc"))
            return CalculatorResult(rows: [
                ResultRow(label: "Add bac water", value: "\(fmt(r.bacWaterMl, 2)) mL", emphasis: true),
                ResultRow(label: "Vial contents", value: "\(fmt(r.vialContentsMcg, 0)) mcg"),
            ], isValid: r.isValid, scheduleLine: nil)

        case .semaglutide, .tirzepatide, .retatrutide:
            let r = glp1(conc: v.number("conc"), dose: v.number("dose"))
            return CalculatorResult(rows: [
                ResultRow(label: "Draw", value: "\(fmt(r.volumeMl, 3)) mL", emphasis: true),
                ResultRow(label: "Units (U-100)", value: fmtInt(r.units), emphasis: true),
            ], isValid: r.isValid, scheduleLine: r.isValid ? volumeMeta(r.volumeMl) : nil, drawMl: r.volumeMl)

        case .bpc157:
            // mcg/mL from vial + water, the web's own derivation (mg × 1000 ÷ mL), so
            // the saved config carries the two real inputs rather than the result.
            let bawMl = v.number("bawMl")
            let conc = bawMl > 0 ? (v.number("vialMg") * 1000) / bawMl : 0
            let r = bpc157(concMcgMl: conc, dose: v.number("dose"))
            return CalculatorResult(rows: [
                ResultRow(label: "Draw", value: "\(fmt(r.drawMl, 3)) mL", emphasis: true),
                ResultRow(label: "Units (U-100)", value: fmtInt(r.units), emphasis: true),
            ], isValid: r.isValid, scheduleLine: r.isValid ? volumeMeta(r.drawMl) : nil, drawMl: r.drawMl)

        case .bpc157blend:
            let r = blend(bpcVial: v.number("bpcVial"), bpcWater: v.number("bpcWater"),
                          bpcDose: v.number("bpcDose"), tbVial: v.number("tbVial"),
                          tbWater: v.number("tbWater"), tbDose: v.number("tbDose"))
            return CalculatorResult(rows: [
                ResultRow(label: "Total draw", value: "\(fmt(r.totalMl, 3)) mL", emphasis: true),
                ResultRow(label: "Total units", value: fmtInt(r.totalUnits), emphasis: true),
                ResultRow(label: "BPC-157 draw", value: "\(fmt(r.bpcDraw, 3)) mL · \(fmtInt(r.bpcUnits)) u"),
                ResultRow(label: "TB-500 draw", value: "\(fmt(r.tbDraw, 3)) mL · \(fmtInt(r.tbUnits)) u"),
            ], isValid: r.isValid, scheduleLine: r.isValid ? volumeMeta(r.totalMl) : nil, drawMl: r.totalMl)

        case .bmi:
            let r = v.bool("imperial")
                ? bmiImperial(heightFt: v.number("heightFt"), heightIn: v.number("heightIn"),
                              weightLb: v.number("weightLb"))
                : bmiMetric(heightCm: v.number("heightCm"), weightKg: v.number("weightKg"))
            return CalculatorResult(rows: [
                ResultRow(label: "BMI", value: fmt(r.bmi, 2), emphasis: true),
                ResultRow(label: "Category", value: r.category, emphasis: true),
            ], isValid: r.isValid, scheduleLine: nil)

        case .freeTestIndex:
            let r = freeTestIndex(ttNum: v.number("tt"),
                                  ttUnit: v.number("ttUnitNgdl") == 1 ? "ngdl" : "nmol",
                                  shbgNum: v.number("shbg"))
            return CalculatorResult(rows: [
                ResultRow(label: "Free Androgen Index", value: fmt(r.fai, 1), emphasis: true),
                ResultRow(label: "Band", value: r.band, emphasis: true),
                ResultRow(label: "TT (nmol/L)", value: fmt(r.ttNmol, 2)),
            ], isValid: r.isValid, scheduleLine: nil)

        case .steroid:
            // The compound picker carries an index into SteroidCatalog.all (the generic
            // picker field stores a Double). Out of range falls back to the first
            // compound rather than returning .empty, so a stale saved config still
            // renders something honest instead of a blank card.
            let idx = Int(v.number("compound"))
            let compound = SteroidCatalog.all.indices.contains(idx)
                ? SteroidCatalog.all[idx]
                : SteroidCatalog.all[0]
            let ester = compound.defaultEster
            let r = steroidInjectable(strength: v.number("strength"),
                                      mgWeek: v.number("mgWeek"),
                                      mode: .ndays,
                                      nDays: v.number("nDays"),
                                      injPerWeek: 0,
                                      mlDrawn: 0,
                                      esterFactor: compound.esterFactor(for: ester),
                                      unitsPerML: scale.unitsPerML)
            let unitLabel = scale == .u100 ? "Units (U-100)" : "Units (U-40)"
            var rows = [
                ResultRow(label: "Draw per injection", value: "\(fmt(r.mlPerInj, 3)) mL", emphasis: true),
                ResultRow(label: unitLabel, value: fmt(r.unitsPerInj, 1), emphasis: true),
                ResultRow(label: "Dose per injection", value: "\(fmt(r.mgPerInj, 2)) mg"),
                ResultRow(label: "Injections / week", value: fmt(r.freqPerWeek, 2)),
                ResultRow(label: "Weekly total", value: "\(fmt(r.weeklyTotal, 1)) mg"),
            ]
            // Active weekly is the steroid-specific number — the ester is dead weight by
            // mass, so this is the hormone actually delivered. Shown only when it differs,
            // since for an esterFactor of 1 it just repeats the line above.
            if compound.esterFactor(for: ester) < 1 {
                rows.append(ResultRow(label: "Active weekly", value: "\(fmt(r.activeWeek, 1)) mg"))
            }
            return CalculatorResult(rows: rows, isValid: r.isValid,
                                    scheduleLine: r.isValid ? volumeMeta(r.mlPerInj) : nil, drawMl: r.mlPerInj)

        case .cyclePlotter:
            // Handled by the bespoke CyclePlotterScreen, not the generic evaluator.
            return .empty
        }
    }

    // Shared TRT-family result formatting.
    private static func trtResult(_ r: TrtResult, scale: SyringeScale) -> CalculatorResult {
        let unitLabel = scale == .u100 ? "Units (U-100)" : "Units (U-40)"
        return CalculatorResult(rows: [
            ResultRow(label: "Draw per injection", value: "\(fmt(r.mlPerInj, 3)) mL", emphasis: true),
            ResultRow(label: unitLabel, value: fmt(r.unitsPerInj, 1), emphasis: true),
            ResultRow(label: "Dose per injection", value: "\(fmt(r.mgPerInj, 2)) mg"),
            ResultRow(label: "Injections / week", value: fmt(r.freqPerWeek, 2)),
            ResultRow(label: "Weekly total", value: "\(fmt(r.weeklyTotal, 1)) mg"),
        ], isValid: r.isValid, scheduleLine: r.isValid ? volumeMeta(r.mlPerInj) : nil, drawMl: r.mlPerInj)
    }
}
