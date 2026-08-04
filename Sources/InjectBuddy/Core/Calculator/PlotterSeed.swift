import Foundation

// ─── PlotterSeed ─────────────────────────────────────────────────────────────
// T-17 — the values a calculator hands the cycle plotter when the user taps
// "See your levels over time". One compound line: what, how much per injection,
// how often.
//
// ─── WHAT THE WEB ACTUALLY DOES, read from the source rather than from T-01a ──
//
// T-01a #3 recorded the difference as "the web link takes you into the plotter
// with this protocol loaded", and T-17 was filed against that. **That is not what
// the web does, and the correction belongs here rather than in a message.** Read on
// `feature/dosage-status-model`:
//
//   • `public/app.js:2400` builds the href as `'/cycle-plotter/?from=' + calcId`.
//     The click handler's ONLY side effect is a PostHog capture — it writes nothing
//     to any store, and no calculator state travels with the link.
//   • `/cycle-plotter/` is a separate legacy bundle. The one place it reads that
//     parameter is `public/legacy/cycle-plotter/app.jsx:366`:
//     `new URLSearchParams(window.location.search).get('from') === 'planner'`.
//     `from=trt` fails that equality, `loadCyclePreset()` returns `null`, and the
//     plotter proceeds exactly as if there were no query string at all.
//
// So on the web, `?from=<calcId>` is a dead parameter for prefill and an analytics
// tag in practice. The user lands on their SAVED protocols (signed in) or on ghost
// curves (signed out), and re-enters the compound and dose either way. iOS's "empty
// plotter" was never a gap against the web; it was parity with it.
//
// ─── WHY THIS IS BUILT ANYWAY ────────────────────────────────────────────────
//
// Because the thing T-01a described is the right behaviour whether or not the web
// has it, and the derivation is not invented: `mapDosage(type, d)`
// (`cycle-plotter/app.jsx:127-215`) is the web's own, authoritative "this protocol's
// config → a plottable line", used for every saved dosage the plotter lists. Every
// formula below is that function, per branch, with its provenance on it. What
// changes is only the SOURCE of the config — the calculator's live values instead of
// a saved row — which is exactly the handoff T-01a asked for and the one thing the
// web never wired up.
//
// ─── AND WHERE IT REFUSES ────────────────────────────────────────────────────
//
// `mapDosage` ends `if (!cid || !(dose > 0) || !COMPOUNDS[cid]) return null;` and
// its steroid map spells out why: *"`null` anywhere means 'we will not draw this',
// and that is a deliberate refusal, not an oversight … a dosing tool does not get to
// guess."* This keeps that. A calculator with no compound iOS can plot seeds
// NOTHING and the CTA opens the plotter unseeded — which is the behaviour that
// shipped, and is still better than a curve drawn for the wrong molecule.

struct PlotterSeed: Hashable {
    /// A `PlotterCompound.id`. Checked against the catalogue before a seed is built,
    /// so a seed always names a compound the plotter can draw.
    let compoundId: String
    /// PER-INJECTION dose in the compound's own unit, never a weekly total.
    /// `mapDosage`: *"dose is normalised to PER-INJECTION because `PK.seriesFor`
    /// applies `p.dose` at each injection time."* `CyclePlotterViewModel` does the
    /// same — `pkBuildEntries(dose:freqDays:)` — so a weekly figure here would plot a
    /// curve several times too high on a screen whose whole output is a level.
    let dose: Double
    /// Days between injections.
    let freqDays: Double
    /// Which calculator it came from — the web's `?from=<calcId>`, kept for the same
    /// reason the web keeps it: so the destination can say where the line came from.
    let sourceSlug: CalculatorSlug
}

extension PlotterSeed {

    /// `ESTER_TO_CID` (`cycle-plotter/app.jsx:47`), verbatim.
    ///
    /// TWO OF THE SEVEN ESTERS MAP TO COMPOUNDS iOS DOES NOT HAVE — `Testosterone
    /// Acetate` → `test-a` and `Sustanon 250` → `sustanon`. They are transcribed
    /// anyway rather than dropped, so this table stays comparable to the web's, and
    /// `compound(_:)` is what refuses them. Filed as T-32.
    ///
    /// `Testosterone Suspension` → `test-p` is the WEB'S approximation, not one made
    /// here: suspension is unesterified and the web plots it on propionate's curve.
    /// Copied as found; changing it would make the two products disagree about a
    /// half-life.
    static let esterToCompoundId: [String: String] = [
        "Testosterone Enanthate": "test-e",
        "Testosterone Cypionate": "test-c",
        "Testosterone Propionate": "test-p",
        "Testosterone Undecanoate": "test-u",
        "Testosterone Acetate": "test-a",
        "Testosterone Suspension": "test-p",
        "Sustanon 250": "sustanon",
    ]

    /// The guard from the bottom of `mapDosage` — a compound id only counts if the
    /// plotter actually carries it.
    private static func compound(_ id: String?) -> String? {
        guard let id, PlotterCompound.all.contains(where: { $0.id == id }) else { return nil }
        return id
    }

    /// `Math.round((7 / ipw) * 100) / 100` — the web rounds the interval to two
    /// decimals so `7 / 3` reads as `2.33` rather than a repeating figure.
    private static func interval(injectionsPerWeek ipw: Double) -> Double {
        guard ipw > 0 else { return 7 }
        return ((7 / ipw) * 100).rounded() / 100
    }

    /// The calculator's live values → one plottable line, or `nil` where the honest
    /// answer is "not this one".
    ///
    /// The `values` bag is the same one `configJSON()` serialises, so this reads the
    /// keys `mapDosage` reads — `esterType`, `mgWeek`, `mode`, `nDays`, `injPerWeek`,
    /// `mlDrawn`, `strength`, `dose` — under the web's own names.
    static func from(slug: CalculatorSlug, values: CalculatorValues) -> PlotterSeed? {
        var cid: String?
        var dose = 0.0
        var freqDays = 7.0

        switch slug {
        case .trt, .microdose:
            // `mapDosage` lines 131-146.
            cid = esterToCompoundId[values.string("esterType")] ?? "test-e"
            let weekly = values.number("mgWeek")
            // `cfg.mode || (cfg.nDays ? 'ndays' : 'perweek')` — microdose has no mode
            // field and does have `nDays`, so it resolves to `ndays`, same as the web.
            let stored = values.string("mode")
            let mode = stored.isEmpty ? (values.numbers["nDays"] != nil ? "ndays" : "perweek") : stored
            if mode == "ndays" {
                freqDays = values.number("nDays") > 0 ? values.number("nDays") : 7
            } else {
                freqDays = interval(injectionsPerWeek: values.number("injPerWeek", 1))
            }
            // mL→mg reverses the calculation: the user typed a VOLUME, so the weekly
            // figure is not the source of truth — the dose is what that volume holds.
            dose = mode == "ml2mg"
                ? values.number("mlDrawn") * values.number("strength")
                : weekly * freqDays / 7

        case .eod:
            // `mapDosage` line 147: the interval is HARDCODED to 2 days, matching the
            // calculator, which is itself hardcoded to every-other-day.
            cid = esterToCompoundId[values.string("esterType")] ?? "test-e"
            freqDays = 2
            dose = values.number("mgWeek") * 2 / 7

        case .semaglutide, .tirzepatide, .retatrutide:
            // `mapDosage` lines 149-157. The iOS specs carry neither `mode` nor
            // `injPerWeek`, so this lands on the web's own fallback — `injPerWeek || 1`
            // → once a week, which is what all three of these calculators mean by
            // "mg per weekly injection" in their own help text.
            //
            // The ids differ between the two plotter catalogues: the web's are
            // `semaglutide`/`tirzepatide`/`retatrutide`, iOS's `PLOTTER_COMPOUNDS`
            // entry is `sema`/`tirz`/`reta`. Mapped here rather than renamed, because
            // the iOS list is transcribed verbatim from `app.js` and a rename would
            // break that provenance for a cosmetic gain.
            switch slug {
            case .semaglutide: cid = "sema"
            case .tirzepatide: cid = "tirz"
            default:           cid = "reta"
            }
            dose = values.number("dose")
            freqDays = interval(injectionsPerWeek: values.number("injPerWeek", 1))

        case .bpc157:
            // `mapDosage` line 165: BPC-157 is dosed daily.
            cid = "bpc157"
            dose = values.number("dose")
            freqDays = 1

        // NO BRANCH, and that is the web's position too rather than a gap here.
        //
        //  • `peptide` — `mapDosage` keys it off `cfg.peptideType`, and the iOS peptide
        //    calculator has no such field: it takes a vial size and a water volume, not
        //    a named peptide. There is nothing to name the curve.
        //  • `reconstitution` and `bpc157blend` — the web has no branch for either.
        //    Reconstitution computes a water volume, and a blend is two compounds,
        //    which is two lines and a decision this seed cannot carry.
        //  • `hcg` — the web maps it to a compound id `hcg`; the iOS plotter catalogue
        //    has no HCG entry, so `compound(_:)` refuses it below. T-32.
        //  • the rest do not show the CTA at all (`PlotLevelsCTA.shows`).
        case .peptide, .reconstitution, .bpc157blend, .hcg,
             .bmi, .freeTestIndex, .cyclePlotter, .steroid:
            return nil
        }

        // `if (!cid || !(dose > 0) || !COMPOUNDS[cid]) return null;`
        guard let id = compound(cid), dose > 0, dose.isFinite,
              freqDays > 0, freqDays.isFinite else { return nil }
        return PlotterSeed(compoundId: id, dose: dose, freqDays: freqDays, sourceSlug: slug)
    }
}
