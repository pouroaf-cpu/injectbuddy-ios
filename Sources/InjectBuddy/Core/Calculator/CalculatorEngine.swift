import Foundation

// ─── CalculatorEngine ────────────────────────────────────────────────────────
// PURE Swift. No UIKit/SwiftUI. Every formula here is ported VERBATIM from the
// web app (Injectbuddy/public/app.js) and locked by CalculatorEngineTests against
// the golden vectors in CALC-MATH.md. JS `Math.round(x)` → `(x).rounded()` (half
// away from zero — Swift's default rounding rule, matching JS round-half-up for the
// non-negative values used here). U-100 convention: `units = mL * 100`.
//
// The engine exposes:
//   • low-level typed compute structs per calculator (used by tests + the VM)
//   • `CalculatorEngine.evaluate(slug:values:scale:)` → CalculatorResult for the UI

enum CalculatorEngine {

    // MARK: - Shared helpers (names scoped to the engine to avoid collisions)

    /// mcg → mg.
    static func mcgToMg(_ mcg: Double) -> Double { mcg / 1000 }
    /// mg → mcg.
    static func mgToMcg(_ mg: Double) -> Double { mg * 1000 }

    /// Injections per week from an "every N days" interval.
    static func freqPerWeek(everyNDays days: Double) -> Double { days > 0 ? 7 / days : 0 }

    /// U-100 units (or scaled) for a drawn volume. The web uses ×100 everywhere
    /// except where U-100/U-40 syringe scaling is explicitly surfaced.
    static func units(forMl ml: Double, unitsPerML: Double = 100) -> Double { ml * unitsPerML }

    /// getVolumeMeta(ml) — qualitative feel of an injection volume.
    static func volumeMeta(_ ml: Double) -> String {
        if ml < 0.01 { return "Too small to measure" }
        if ml < 0.03 { return "Difficult to measure" }
        if ml < 0.1  { return "Acceptable" }
        if ml <= 0.5 { return "Ideal" }
        if ml <= 1   { return "Good" }
        if ml <= 3   { return "Large injection" }
        return "Unrealistic volume"
    }

    /// BMI category bands.
    static func bmiCategory(_ bmi: Double) -> String {
        if bmi < 18.5 { return "Underweight" }
        if bmi < 25   { return "Normal" }
        if bmi < 30   { return "Overweight" }
        if bmi < 35   { return "Obesity I" }
        if bmi < 40   { return "Obesity II" }
        return "Obesity III"
    }

    /// Free Androgen Index band: <30 Low; >150 Elevated; else Normal.
    static func faiBand(_ fai: Double) -> String {
        if fai < 30 { return "Low" }
        if fai > 150 { return "Elevated" }
        return "Normal"
    }

    // T-42 — REMOVED: `testoNgdlFactor = 13.5`, described here as an "ng/dL
    // calibration for testosterone esters (plotter)". It was a calibration of
    // nothing: the live plotter's own FAQ names volume of distribution and
    // bioavailability, BOTH COMPOUND-SPECIFIC, as what an ng/dL conversion needs
    // (`public/legacy/cycle-plotter/index.html:2297`), and one global scalar
    // cannot encode a per-compound parameter, let alone two. It was gated on
    // all-testosterone selections, so it stood in for the Vd AND bioavailability
    // of FOUR different esters at once — enanthate, cypionate, propionate and
    // undecanoate, whose half-lives alone run 0.8 to 21 days. No single value
    // makes it correct for all four. `spec/math-spec.md`
    // §4.1: "A port must not add a unit conversion here." The plotter now plots
    // `pkTotalLevel` unscaled and labels it `relative units`, as the web does.
    // Its single reader was `CyclePlotterViewModel.rebuild`; `scripts/unread-decls.py`
    // then reported it unread, which is why it is deleted rather than left orphaned.

    // MARK: - trt / eod / microdose

    enum TrtMode: String { case ndays, perweek, ml2mg }

    struct TrtResult: Equatable {
        var freqPerWeek: Double
        var mgPerInj: Double
        var mlPerInj: Double
        var unitsPerInj: Double
        var weeklyTotal: Double
        var isValid: Bool
    }

    /// trt-dose / trt-microdose (same engine). Ported verbatim.
    static func trt(strength: Double, mgWeek: Double, mode: TrtMode,
                    nDays: Double, injPerWeek: Double, mlDrawn: Double,
                    unitsPerML: Double = 100) -> TrtResult {
        var freq = 0.0, mgPerInj = 0.0, mlPerInj = 0.0, weeklyTotal = 0.0
        switch mode {
        case .ndays:
            freq = 7 / nDays
            mgPerInj = mgWeek / freq
            mlPerInj = mgPerInj / strength
            weeklyTotal = mgWeek
        case .perweek:
            freq = injPerWeek
            mgPerInj = mgWeek / freq
            mlPerInj = mgPerInj / strength
            weeklyTotal = mgWeek
        case .ml2mg:
            mlPerInj = mlDrawn
            mgPerInj = mlDrawn * strength
            freq = injPerWeek
            weeklyTotal = mgPerInj * freq
        }
        let unitsPerInj = mlPerInj * unitsPerML
        let isValid = strength > 0 && mlPerInj > 0 && mlPerInj.isFinite
        return TrtResult(freqPerWeek: freq, mgPerInj: mgPerInj, mlPerInj: mlPerInj,
                         unitsPerInj: unitsPerInj, weeklyTotal: weeklyTotal, isValid: isValid)
    }

    // MARK: - steroid (injectable + oral)

    struct SteroidInjectableResult: Equatable {
        var freqPerWeek: Double
        var mgPerInj: Double
        var mlPerInj: Double
        var unitsPerInj: Double
        var weeklyTotal: Double
        /// Weekly ACTIVE hormone — weeklyTotal × esterFactor. The ester is dead weight
        /// by mass, so 200mg of Deca carries 128mg of nandrolone.
        var activeWeek: Double
        var isValid: Bool
    }

    struct SteroidOralResult: Equatable {
        var perDoseMg: Double
        var tabsPerDose: Double
        var isValid: Bool
    }

    /// Injectable steroid dosing. The web says it outright — "Injectable calc —
    /// identical to TRTPage" — so this delegates to `trt` rather than restating the
    /// arithmetic, and adds only the one steroid-specific quantity on top.
    static func steroidInjectable(strength: Double, mgWeek: Double, mode: TrtMode,
                                  nDays: Double, injPerWeek: Double, mlDrawn: Double,
                                  esterFactor: Double, unitsPerML: Double = 100) -> SteroidInjectableResult {
        let t = trt(strength: strength, mgWeek: mgWeek, mode: mode, nDays: nDays,
                    injPerWeek: injPerWeek, mlDrawn: mlDrawn, unitsPerML: unitsPerML)
        return SteroidInjectableResult(freqPerWeek: t.freqPerWeek,
                                       mgPerInj: t.mgPerInj,
                                       mlPerInj: t.mlPerInj,
                                       unitsPerInj: t.unitsPerInj,
                                       weeklyTotal: t.weeklyTotal,
                                       activeWeek: t.weeklyTotal * esterFactor,
                                       isValid: t.isValid)
    }

    /// Oral steroid dosing. Orals have no syringe: a daily milligram total is split
    /// into `split` doses, then converted to whole-ish tablets at `tabMg` each.
    /// Ported verbatim — validity is `tabsPerDose` being finite, exactly as the web
    /// gates it, so a zero tablet strength is invalid rather than infinite.
    static func steroidOral(doseMgPerDay: Double, tabMg: Double, split: Double) -> SteroidOralResult {
        let perDoseMg = (doseMgPerDay.isFinite && split.isFinite && split > 0) ? doseMgPerDay / split : Double.nan
        let tabsPerDose = (perDoseMg.isFinite && tabMg.isFinite && tabMg > 0) ? perDoseMg / tabMg : Double.nan
        return SteroidOralResult(perDoseMg: perDoseMg, tabsPerDose: tabsPerDose,
                                 isValid: tabsPerDose.isFinite)
    }

    /// trt-eod — hardcoded 3.5 injections/week.
    static func eod(strength: Double, mgWeek: Double, unitsPerML: Double = 100) -> TrtResult {
        let freq = 3.5
        let mgPerInj = mgWeek / freq
        let mlPerInj = mgPerInj / strength
        let unitsPerInj = mlPerInj * unitsPerML
        let isValid = strength > 0 && mlPerInj > 0 && mlPerInj.isFinite
        return TrtResult(freqPerWeek: freq, mgPerInj: mgPerInj, mlPerInj: mlPerInj,
                         unitsPerInj: unitsPerInj, weeklyTotal: mgWeek, isValid: isValid)
    }

    // MARK: - hcg

    struct HcgResult: Equatable {
        var concentration: Double  // IU/mL
        var drawMl: Double
        var units: Double
        var dosesPerVial: Double
        var isValid: Bool
    }

    static func hcg(vialIU: Double, bacWaterMl: Double, dose: Double) -> HcgResult {
        let concentration = bacWaterMl > 0 ? vialIU / bacWaterMl : 0
        let drawMl = concentration > 0 ? dose / concentration : 0
        let units = (drawMl * 100).rounded()
        let dosesPerVial = dose > 0 ? (vialIU / dose).rounded(.down) : 0
        return HcgResult(concentration: concentration, drawMl: drawMl, units: units,
                         dosesPerVial: dosesPerVial, isValid: drawMl > 0)
    }

    // MARK: - peptide

    struct PeptideResult: Equatable {
        var dosePerInjMg: Double
        var concentration: Double  // mg/mL
        var mlPerInj: Double
        var unitsPerInj: Double
        var weeklyTotalMg: Double
        var totalDoses: Double
        var vialDays: Double
        var vialWeeks: Double
        var isValid: Bool
    }

    /// doseUnit: "mcg" or "mg".
    static func peptide(peptideMg: Double, bawMl: Double, dosePerInj: Double,
                        doseUnit: String, injPerWeek: Double) -> PeptideResult {
        let dosePerInjMg = doseUnit == "mcg" ? dosePerInj / 1000 : dosePerInj
        let concentration = bawMl > 0 ? peptideMg / bawMl : 0
        let mlPerInj = (concentration > 0 && dosePerInjMg > 0) ? dosePerInjMg / concentration : 0
        let unitsPerInj = mlPerInj * 100
        let weeklyTotalMg = dosePerInjMg * injPerWeek
        let totalDoses = dosePerInjMg > 0 ? peptideMg / dosePerInjMg : 0
        let vialDays = injPerWeek > 0 ? totalDoses / (injPerWeek / 7) : 0
        let vialWeeks = vialDays / 7
        return PeptideResult(dosePerInjMg: dosePerInjMg, concentration: concentration,
                             mlPerInj: mlPerInj, unitsPerInj: unitsPerInj,
                             weeklyTotalMg: weeklyTotalMg, totalDoses: totalDoses,
                             vialDays: vialDays, vialWeeks: vialWeeks, isValid: mlPerInj > 0)
    }

    // MARK: - reconstitution

    struct ReconResult: Equatable {
        var bacWaterMl: Double
        var vialContentsMcg: Double
        var isValid: Bool
    }

    /// targetConc in mcg/mL.
    static func reconstitution(peptideMg: Double, targetConc: Double) -> ReconResult {
        let bacWaterMl = targetConc > 0 ? (peptideMg * 1000) / targetConc : 0
        let vialContentsMcg = peptideMg * 1000
        return ReconResult(bacWaterMl: bacWaterMl, vialContentsMcg: vialContentsMcg,
                           isValid: bacWaterMl > 0)
    }

    // MARK: - semaglutide / tirzepatide / retatrutide (identical engine)

    struct GlpResult: Equatable {
        var volumeMl: Double
        var units: Double
        var isValid: Bool
    }

    /// conc mg/mL, dose mg.
    static func glp1(conc: Double, dose: Double) -> GlpResult {
        let volumeMl = (conc > 0 && dose > 0) ? dose / conc : 0
        let units = (volumeMl * 100).rounded()
        return GlpResult(volumeMl: volumeMl, units: units, isValid: volumeMl > 0)
    }

    // MARK: - bpc-157

    struct DrawResult: Equatable {
        var drawMl: Double
        var units: Double
        var isValid: Bool
    }

    /// concMcgMl in mcg/mL, dose in mcg.
    static func bpc157(concMcgMl: Double, dose: Double) -> DrawResult {
        let conc = concMcgMl
        let drawMl = (conc > 0 && dose > 0) ? dose / conc : 0
        let units = (drawMl * 100).rounded()
        return DrawResult(drawMl: drawMl, units: units, isValid: drawMl > 0)
    }

    // MARK: - bpc-157-tb500 (blend)

    struct BlendResult: Equatable {
        var bpcConc: Double
        var bpcDraw: Double
        var bpcUnits: Double
        var tbConc: Double
        var tbDraw: Double
        var tbUnits: Double
        var totalMl: Double
        var totalUnits: Double
        var isValid: Bool
    }

    static func blend(bpcVial: Double, bpcWater: Double, bpcDose: Double,
                      tbVial: Double, tbWater: Double, tbDose: Double) -> BlendResult {
        let bpcConc = bpcWater > 0 ? bpcVial / bpcWater : 0
        let bpcDraw = (bpcConc > 0 && bpcDose > 0) ? bpcDose / bpcConc : 0
        let bpcUnits = (bpcDraw * 100).rounded()
        let tbConc = tbWater > 0 ? tbVial / tbWater : 0
        let tbDraw = (tbConc > 0 && tbDose > 0) ? tbDose / tbConc : 0
        let tbUnits = (tbDraw * 100).rounded()
        let totalMl = bpcDraw + tbDraw
        let totalUnits = bpcUnits + tbUnits
        return BlendResult(bpcConc: bpcConc, bpcDraw: bpcDraw, bpcUnits: bpcUnits,
                           tbConc: tbConc, tbDraw: tbDraw, tbUnits: tbUnits,
                           totalMl: totalMl, totalUnits: totalUnits,
                           isValid: totalMl > 0)
    }

    // MARK: - bmi

    struct BmiResult: Equatable {
        var bmi: Double
        var category: String
        var isValid: Bool
    }

    /// metric path. heightCm, weightKg.
    static func bmiMetric(heightCm: Double, weightKg: Double) -> BmiResult {
        let hm = heightCm / 100
        let bmi = (hm > 0) ? weightKg / (hm * hm) : .nan
        return BmiResult(bmi: bmi, category: bmi.isFinite ? bmiCategory(bmi) : "—",
                         isValid: bmi.isFinite && bmi > 0)
    }

    /// imperial path. heightFt + heightIn, weightLb.
    static func bmiImperial(heightFt: Double, heightIn: Double, weightLb: Double) -> BmiResult {
        let totalIn = heightFt * 12 + heightIn
        let bmi = (totalIn > 0) ? 703 * weightLb / (totalIn * totalIn) : .nan
        return BmiResult(bmi: bmi, category: bmi.isFinite ? bmiCategory(bmi) : "—",
                         isValid: bmi.isFinite && bmi > 0)
    }

    // MARK: - free-testosterone-index (FAI)

    struct FaiResult: Equatable {
        var ttNmol: Double
        var fai: Double
        var band: String
        var isValid: Bool
    }

    /// ttUnit: "ngdl" or "nmol". shbg in nmol/L.
    static func freeTestIndex(ttNum: Double, ttUnit: String, shbgNum: Double) -> FaiResult {
        let ttNmol = ttUnit == "ngdl" ? ttNum / 28.84 : ttNum
        let valid = ttNmol.isFinite && shbgNum > 0
        let fai = valid ? (ttNmol / shbgNum) * 100 : .nan
        return FaiResult(ttNmol: ttNmol, fai: fai,
                         band: fai.isFinite ? faiBand(fai) : "—", isValid: fai.isFinite)
    }

    // MARK: - cycle-plotter PK model
    // Ported verbatim from app.js: pkSolveKa, pkOneLevel, pkBuildEntries, pkTotalLevel.
    // Single-compartment first-order absorption/elimination (Bateman function).

    struct PKDoseEntry {
        let doseTime: Double
        let dose: Double
        let ke: Double
        let ka: Double
    }

    /// pkSolveKa — bisection solving for the absorption rate that yields the given tmax.
    static func pkSolveKa(ke: Double, tmax: Double) -> Double {
        var lo = ke * 1.0001, hi = ke * 200000
        for _ in 0..<100 {
            let mid = (lo + hi) / 2
            let val = Foundation.log(mid / ke) / (mid - ke)
            if val > tmax { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    /// pkOneLevel — contribution of a single dose at elapsed time `dt`.
    static func pkOneLevel(dt: Double, dose: Double, ke: Double, ka: Double) -> Double {
        if dt <= 0 { return 0 }
        return dose * (ka / (ka - ke)) * (exp(-ke * dt) - exp(-ka * dt))
    }

    /// pkBuildEntries — one dosing event every `freqDays` across the cycle.
    static func pkBuildEntries(halfLife: Double, tmax: Double, dose: Double,
                               freqDays: Double, cycleDays: Double) -> [PKDoseEntry] {
        let ke = M_LN2 / halfLife
        let ka = pkSolveKa(ke: ke, tmax: tmax)
        var entries: [PKDoseEntry] = []
        var t = 0.0
        while t < cycleDays {
            entries.append(PKDoseEntry(doseTime: t, dose: dose, ke: ke, ka: ka))
            t += freqDays
        }
        return entries
    }

    /// pkTotalLevel — summed plasma level at time `t` from all doses.
    static func pkTotalLevel(t: Double, entries: [PKDoseEntry]) -> Double {
        entries.reduce(0) { $0 + pkOneLevel(dt: t - $1.doseTime, dose: $1.dose, ke: $1.ke, ka: $1.ka) }
    }
}
