import Foundation

// ─── CalculatorDescriptions ──────────────────────────────────────────────────
// The one-line description under each calculator on a browse surface — T-01e.
//
// WHAT WAS WRONG: every web calculator card carries two or three lines saying what
// the tool is for; iOS's Tools rows carried a title and an icon and nothing else. On
// a list of fifteen names, several of which differ by one word — `TRT Dose`,
// `TRT & EOD`, `TRT Microdose` — a title alone does not tell you which one you want,
// and the user picks by guessing or by opening three of them.
//
// TRANSCRIBED VERBATIM from `CALC_DESC` in `public/app.js` on branch
// `feature/dosage-status-model` (NOT `master` — the two differ by 1038 insertions).
// Not paraphrased: this is user-facing copy that the web has already settled, and
// rewording it here would mean two products describing the same tool differently to
// the same person.
//
// ── WHY THIS IS ITS OWN FILE ────────────────────────────────────────────────────
// It belongs on `CalculatorSlug` in `Core/Nav/NavItems.swift`, beside `title`,
// `shortTitle` and `icon`. It is here because that file was being edited by another
// agent for T-17 when this was written, and two agents in one file is how a morning's
// work shipped under someone else's commit message today. **Fold this into
// `NavItems.swift` once T-17 lands** — it is an extension on the same type, so the
// move is a cut and paste with no call-site change. Recorded rather than left to be
// discovered.
//
// THE THREE ABSENT ENTRIES ARE THE HONEST ANSWER, not an oversight: `CALC_DESC` also
// carries `ftv`, `reverse`, `blend`, `glp1titration`, `femalehrt`, `nootropic`,
// `e2estimator` and `bioavailability` — the eight calculators iOS does not have
// (T-19). They are deliberately not transcribed. A description for a screen that does
// not exist is a promise this app cannot keep.

extension CalculatorSlug {
    /// One line saying what this calculator is for. `CALC_DESC`, verbatim.
    var blurb: String {
        switch self {
        case .trt:            return "Find your testosterone dose and injection volume."
        case .eod:            return "Split a weekly Testosterone (TRT) dose into every-other-day jabs."
        case .microdose:      return "Plan daily or EOD testosterone microdoses."
        case .hcg:            return "Reconstitute HCG and convert IU to units."
        case .peptide:        return "Reconstitute a peptide vial and read your units."
        case .reconstitution: return "Convert mg, BAC water and dose into units."
        case .semaglutide:    return "Reconstitute semaglutide and dose it in units."
        case .tirzepatide:    return "Reconstitute tirzepatide and dose it in units."
        case .retatrutide:    return "Reconstitute retatrutide and dose it in units."
        case .bpc157:         return "Dose a BPC-157 vial in syringe units."
        case .bpc157blend:    return "Dose a combined BPC-157 + TB-500 vial."
        case .steroid:        return "Convert a steroid dose to mL, units or tablets."
        case .cyclePlotter:   return "Graph estimated blood levels over time."
        case .bmi:            return "Check body mass index from height and weight."
        case .freeTestIndex:  return "Estimate free testosterone from total and SHBG."
        }
    }
}
