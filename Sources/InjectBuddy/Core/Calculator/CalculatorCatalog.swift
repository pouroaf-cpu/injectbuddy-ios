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
    // ── THE GLP-1 LADDERS  (T-45) ────────────────────────────────────────────
    //
    // `SEMA_DOSE_VALUES` / `TIRZ_DOSE_VALUES` / `RETA_DOSE_VALUES` / `GLP1_CONC_VALUES`,
    // now COMPLETE. Verified against three sources on 2026-08-04 and all three agree
    // on these four arrays to the value: the web working tree (`master`),
    // `public/app.js` on `feature/dosage-status-model`, and the DEPLOYED bundle
    // (`https://www.injectbuddy.com/app.js?v=e10ca869`).
    //
    // WHAT THEY USED TO BE, because the shape of the truncation is the finding:
    //
    //   semaDoses  11 of 22, last 2.4    tirzDoses   7 of 17, last 15
    //   retaDoses  16 of 22, last 12     glp1Concs  12 of 17, last 20
    //
    // Every one of the three dose lists was cut at EXACTLY the web's warning
    // threshold (2.4 / 15 / 12 — see `weeklyMaxMg` below). So iOS was enforcing the
    // ceiling by DELETING the option rather than by warning about it, and the
    // sentence explaining why the value needs care went with it: a user prescribed
    // above the Wegovy/SURMOUNT ceiling got no guidance at all where the web gives
    // them a message. Restoring the list without restoring the warning would have
    // been half a fix; `weeklyMaxMg` is the other half and they land together.
    //
    // THESE ARE GRADATIONS, NOT THE REACHABLE SET, and that distinction is the rest
    // of T-45. On the web they feed a ruler (`DrumPicker`) and supply the bounds of a
    // typed box — the value the user commits need not be on a tick. iOS now spends
    // them as `drum:` on a `.number` field for the same reason. Spending them as
    // `.picker` options, which is what this file used to do, made the array the
    // complete set of expressible concentrations: a 12 mg/mL compounded vial — a
    // strength the web's OWN FAQ names — had no correct option, and the nearest
    // choice over-drew.
    static let semaDoses: [Double] = [
        0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.4, 2.5,
        3, 3.5, 4, 4.5, 5, 5.5, 6, 6.5, 7, 7.5,
    ]
    static let tirzDoses: [Double] = [
        0, 2.5, 5, 7.5, 10, 12.5, 15, 17.5, 20, 22.5, 25, 27.5, 30, 32.5, 35, 37.5, 40,
    ]
    static let retaDoses: [Double] = [
        0, 0.5, 1, 1.5, 2, 2.5, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
        14, 16, 18, 20, 22, 24,
    ]
    static let glp1Concs: [Double] = [
        0, 1, 2, 2.5, 3, 4, 5, 7.5, 10, 12.5, 15, 20, 25, 30, 40, 50, 60,
    ]

    /// The web's per-compound *typical weekly maximum*, in mg — the threshold that
    /// raises an `InfoBox` on the GLP-1 pages, NOT a cap. `app.js`:
    ///
    ///     isValid && dose > 2.4  →  'Exceeds typical weekly maximum of 2.4 mg — …'
    ///     isValid && dose > 15   →  '… 15 mg — …'
    ///     isValid && dose > 12   →  '… 12 mg — …'
    ///
    /// The number is repeated inside the sentence on the web, so it is formatted from
    /// this one value rather than written twice — a threshold that drifts from its own
    /// copy is a warning that names the wrong ceiling.
    static func weeklyMaxMg(for slug: CalculatorSlug) -> Double? {
        switch slug {
        case .semaglutide:  return 2.4
        case .tirzepatide:  return 15
        case .retatrutide:  return 12
        default:            return nil
        }
    }

    /// Verbatim from the three GLP-1 pages, em dash and all. The trailing clause is
    /// the whole point of the message: it tells the user what to DO, which is the
    /// part a truncated list could not say.
    static func weeklyMaxNote(_ maxMg: Double) -> String {
        let n = maxMg == maxMg.rounded() ? String(Int(maxMg)) : String(maxMg)
        return "Exceeds typical weekly maximum of \(n) mg — verify with your prescriber."
    }

    /// `isValid && volumeMl < 0.01` on all three GLP-1 pages. The other half of the
    /// pair, and the one that fires at the SMALL end: a draw under one insulin unit
    /// cannot be measured accurately on a U-100 barrel.
    static let subUnitDrawNote =
        "Draw is less than 1 unit — accuracy may be limited at this scale."

    static func doseOptions(_ values: [Double]) -> [CalculatorInput.PickerOption] {
        values.map { v in
            CalculatorInput.PickerOption(label: v == v.rounded() ? String(Int(v)) : String(v), value: v)
        }
    }
}

// MARK: - Plotter compound list
//
// ─── T-60: THIS TABLE USED TO SAY "verbatim from app.js PLOTTER_COMPOUNDS" ───
//
// That comment was ACCURATE, and that was the defect. `PLOTTER_COMPOUNDS`
// (`public/app.js:10736`) is DEAD: the in-app plotter was removed in favour of
// the standalone `/cycle-plotter/` page, `App()` redirects `plotter` straight
// there (`app.js:11300`), and nothing reads that table any more. The LIVE
// plotter loads `public/legacy/cycle-plotter/pk.js`.
//
// So iOS faithfully copied a corpse, and ran **17 wrong half-lives and 4 wrong
// units** — Tren A 1.5 vs 3.0 (2×), PT-141 0.113 vs 0.5 (4.4×), TB-500 0.58 vs
// 2.5 (4.3×), Melanotan II 3.7 vs 1.5 (2.5×). Only 6 of 23 comparable rows
// agreed. A half-life drives the entire accumulation curve, so every one of
// those drew a confident wrong picture of a real protocol.
//
// Nothing detected it because the two tables use different id vocabularies
// (`eq` vs `boldenone`, `reta` vs `retatrutide`), so a comparison by id found
// nothing to compare. The ids below are now the spec's.
//
// ─── WHERE THE ROWS COME FROM NOW ───────────────────────────────────────────
//
// `all` is **generated** — see `PlotterCompoundTable.swift`, emitted by
// `spec/generate-plotter-compounds.mjs` from `spec/compounds.json` (a
// byte-identical copy of the web's, verified by git blob hash) plus
// `spec/plotter-ios-fields.json` for the two fields the spec has no counterpart
// for. It is generated rather than re-typed because a second faithful hand-copy
// — of the right table this time — sits exactly one refactor away from the
// position this task had to dig out of. `PlotterCompoundSpecTests` re-reads the
// spec at test time and asserts the shipped table against it row for row.
//
// ─── `tmax` AND `defaultDose` ARE NOT SPEC-BACKED ───────────────────────────
//
// `spec/compounds.json` has no `tmax` field at all; the live `pk.js` never names
// one, deriving `ka = ln2 / max(0.01, halfLife × 0.25)` analytically instead.
// Both fields are still the dead table's numbers. They were deliberately left
// alone by T-60 — deleting `tmax` would leave `pkBuildEntries` with no
// absorption input, and inventing replacements would put a fabricated number on
// a dosing curve. iOS's ka-by-bisection is already recorded as a divergence in
// T-42, which is where that decision belongs. `defaultDose` is read by nothing.

struct PlotterCompound: Identifiable, Equatable {
    /// The LIVE plotter's id (`pk.js` / `spec/compounds.json`), not the dead
    /// table's. `deca`→`nandrolone-d`, `eq`→`boldenone`, `mast-p`→`masteron-p`,
    /// `mast-e`→`masteron-e`, `sema`/`tirz`/`reta`→ the full names.
    let id: String
    /// The spec's `name`.
    let label: String
    /// The spec's `short` — the compact form the web's own picker uses. Carried
    /// so the drift test can assert it; no iOS surface renders it yet.
    let short: String
    /// The spec's `type`: `trt` | `peptide` | `glp1`. Same reason as `short`.
    let type: String
    /// The spec's `cat`.
    ///
    /// **THIS COMMENT USED TO SAY the category was load-bearing because
    /// `CyclePlotterViewModel` gated the ng/dL factor on it being `"Testosterone"`.
    /// T-42 deleted that factor, so the gate it described no longer exists** — the
    /// sentence outlived the code by about an hour. Left visible rather than silently
    /// swapped, because a comment asserting a coupling that has been removed is exactly
    /// what makes the next reader preserve something for a reason that is gone.
    ///
    /// It is still read — `test_theTestosteroneCategoryStillSelectsExactlyTheEsters`
    /// pins it, and the picker groups by it — but it is no longer a dosing gate.
    /// The four rows the live table has no entry for keep the dead table's
    /// off-vocabulary `"Peptide"`, which is how they are identifiable as
    /// non-spec rows.
    let category: String
    /// Days. **Spec-backed.**
    let halfLife: Double
    /// Days. NOT spec-backed — see the note above.
    let tmax: Double
    /// NOT spec-backed, and read by nothing. For `tb500`, `hgh`, `pt141` and
    /// `mt2` it is still expressed in the dead table's `mcg` while `unit` is now
    /// the live one; `spec/plotter-ios-fields.json` → `staleDefaultDoseUnit`
    /// records that, and the generator refuses any further mismatch.
    let defaultDose: Double
    /// `"mg"`, `"mcg"` or `"IU"`. **Spec-backed** — `IU` arrived with T-60 (HGH).
    let unit: String

    // `static let all` is GENERATED — see `PlotterCompoundTable.swift`.

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

    /// The three dosing modes, verbatim from `app.js:8396`:
    /// `[{label:'Every N Days',value:'ndays'},{label:'Per Week',value:'perweek'},
    ///   {label:'mL → mg',value:'ml2mg'}]`.
    ///
    /// The VALUES are what reach `config.mode` and they are the web's strings
    /// exactly. `CalculatorEngine.TrtMode` already spells them the same way, which
    /// is why the engine needed no new cases for T-01a #1 — only a caller that
    /// stopped hardcoding one of them.
    static let trtModeOptions: [CalculatorInput.ModeOption] = [
        .init(label: "Every N Days", value: "ndays"),
        .init(label: "Per Week", value: "perweek"),
        .init(label: "mL → mg", value: "ml2mg"),
    ]

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
        // `compound` is an index into SteroidCatalog.picks — an iOS implementation
        // detail; the web keys the compound by its slug string and its ester
        // separately. The oral trio are iOS NUMBER fields whose web counterparts are
        // the raw input STRINGS `dose` / `tab` / `split`. Both groups are re-emitted
        // with the web's name and type by configExtras below, so THE KEY SET IS
        // UNCHANGED by T-44 — see the test.
        case .steroid: return ["compound", "oralDose", "tabMg", "oralSplit"]
        default: return []
        }
    }

    /// Keys the web writes that the iOS form has no field for.
    static func configExtras(for slug: CalculatorSlug, values v: CalculatorValues) -> [String: JSONValue] {
        switch slug {
        case .trt:
            // EMPTY, as of T-01a #1, and the emptiness is the fix.
            //
            // This used to hardcode `mode: "perweek"`, `nDays: 3.5`, `mlDrawn: 0.5`
            // with the note "evaluate() runs TRT in perweek mode, so that is the
            // honest value here". It was honest about the ENGINE and dishonest about
            // the USER: all three are now real, visible fields, and extras WIN over
            // field values in `configJSON()` — so leaving any of them here would
            // silently overwrite the mode the user just picked with `perweek`, which
            // is exactly the failure mode this file's own `syringeMl` note warns
            // about two screens up.
            //
            // The key set reaching `config` is unchanged; only its source is.
            return [:]

        case .eod:
            // Web's EOD lives on the MicrodoseTRT page, whose barrel default is 0.3 —
            // now carried by barrelField's default rather than hardcoded here.
            return [:]

        case .microdose:
            return ["mode": .string("ndays"), "injPerWeek": .number(0),
                    "mlDrawn": .number(0.5), "esterType": .string("")]

        case .hcg:
            // The web's HCG rows carry ONLY bacWaterMl/dose/syringeMl/vialIU — no
            // mode, nDays or injPerWeek. Verified against the live table, not against
            // this file. Emitting the injectable family's mode pair here made every
            // iOS HCG save a different config from the equivalent web row.
            return [:]

        // ── THE COMMENT THAT USED TO BE HERE WAS BACKWARDS  (corrected T-45) ──
        //
        // It read: *"The three GLP-1 slugs do NOT share a config shape on the web…
        // Semaglutide rows carry the mode pair; tirzepatide and retatrutide rows carry
        // only conc/dose/syringeMl. Grouping them in one case is what made two of the
        // three mismatch."* Every clause of that is inverted, and both sides have now
        // confirmed it against the source rather than against each other's notes.
        //
        // THE TRUTH: all three pages write the SAME SIX KEYS.
        // `SemaglutidePage.handleSave`, `TirzepatidePage.handleSave` and
        // `RetatrutidePage.handleSave` each build
        // `config = {conc, dose, syringeMl, mode, nDays, injPerWeek}` — three identical
        // sites, present on `master`, on `feature/dosage-status-model` AND in the
        // deployed bundle. So SPLITTING them into two cases is what made two of the
        // three mismatch, not grouping them.
        //
        // CONSEQUENCE, still live: iOS writes three keys for tirzepatide and
        // retatrutide where the web writes six. The unique index covers the WHOLE
        // config, so every iOS row of those two types is a different protocol from the
        // equivalent web row — the same protocol saved on both platforms exists twice —
        // and `loadDosage` reads `cfg.mode`/`cfg.nDays`/`cfg.injPerWeek`, so an iOS row
        // reopens on the web at `perweek`/7/1 whatever the user chose. It does NOT move
        // the schedule: `deriveDose`'s GLP-1 branch hardcodes `freqDays: 7` and reads
        // only `dose`, `conc` and `syringeMl`.
        //
        // THE KEYS ARE DELIBERATELY NOT CHANGED IN THIS COMMIT. Adding three keys here
        // re-fingerprints every future tirzepatide and retatrutide save, which is a
        // migration question about rows that already exist (retatrutide is the third
        // largest protocol group in production) and not a side effect to slip in behind
        // an option-list fix. It is T-01b-4 #2 / T-01b-5 #2 and it must be closed with a
        // row read back out of the database, not with a diff.
        case .semaglutide:
            return ["mode": .string("perweek"),
                    "nDays": .number(7), "injPerWeek": .number(1)]

        case .tirzepatide, .retatrutide:
            return [:]

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
            let pick = SteroidCatalog.pick(at: Int(v.number("compound")))
            // `form` is DERIVED, not stored, and it is derived exactly as the web
            // derives its initial value: `useState(canInject ? 'injectable' : 'oral')`
            // (`app.js:8789`, off `cls` at 8787-8788). The web only ever offers the
            // toggle when a compound has both forms — `(canInject && canOral)`,
            // `app.js:8944` — which is Winstrol alone; iOS has no toggle yet, so
            // every compound sits on the form the web opens it on.
            let isOral = !pick.compound.canInject
            var out: [String: JSONValue] = [
                "slug": .string(pick.compound.key),
                "form": .string(isOral ? "oral" : "injectable"),
                "mode": .string("ndays"),
                "esterKey": .string(pick.ester?.key ?? ""),
                "injPerWeek": .number(2),
                "mlDrawn": .number(0.5),
            ]
            if isOral {
                // The oral trio carry the real inputs, as strings — the web's `dose`
                // / `tab` / `split` are `<input>` state (`app.js:8810-8812, 8866`).
                out["dose"] = .string(SteroidCatalog.inputString(v.number("oralDose")))
                out["tab"] = .string(SteroidCatalog.inputString(v.number("tabMg")))
                out["split"] = .string(SteroidCatalog.inputString(v.number("oralSplit")))
                // The web's oral page never touches the weekly-dose state, so it saves
                // `mgWeek: 0` (`useState(0)`, `app.js:8804`). iOS's hidden field would
                // otherwise carry its injectable default of 300 into an oral row — a
                // weekly injectable dose stored against a tablet. Safe to set: an oral
                // steroid could not be saved AT ALL before this change, so there are no
                // rows for it to re-fingerprint. The other five injectable keys already
                // agree with the web's untouched state (strength 200 = `d.defaultConc ||
                // 200`, nDays 3.5, injPerWeek 2, mlDrawn 0.5, syringeMl 1).
                out["mgWeek"] = .number(0)
            } else {
                // Byte-for-byte what an injectable steroid save has always written.
                //
                // NOT "corrected" here, deliberately. The web's untouched `tab` on an
                // injectable page is `String(defTab)` — "10", or "50" on Anadrol — not
                // `""`, so this line is a known deviation. But `saved_dosages` is
                // de-duplicated on the WHOLE config, so changing a value every future
                // injectable row carries would re-fingerprint all of them against the
                // rows already in production. That is a data decision, not a tidy;
                // reported against T-44 rather than taken.
                out["dose"] = .string("")
                out["tab"] = .string("")
                out["split"] = .string("1")
            }
            return out

        case .bmi, .freeTestIndex, .cyclePlotter:
            // Never saved — canSaveProtocol is false.
            return [:]
        }
    }

    /// The INVERSE of `CalculatorViewModel.configJSON()` — a saved `config` read back
    /// into the value bag `CalculatorEngine.evaluate` takes.
    ///
    /// Exists so a saved protocol can be re-evaluated without a screen. The one caller
    /// today is `DoseVolume.perInjectionMl`, which needs the draw volume for a dose that
    /// is being LOGGED, long after the calculator that produced it went away.
    ///
    /// Seeded from the spec defaults and then overwritten key by key, never built from
    /// zero: a config missing a key must fall back to what the form would have shown,
    /// not to 0. A 0 strength divides into an infinite volume.
    ///
    /// The two `configOmittedKeys` inversions are done explicitly, because they are the
    /// keys the web writes under a DIFFERENT NAME AND TYPE from the iOS field, so the
    /// loop above cannot see them: `peptide.doseUnit` ("mcg"/"mg") is the iOS
    /// `doseUnitMcg` picker (1/0), and `steroid.slug` + `steroid.esterKey` together are
    /// the iOS `compound` index into `SteroidCatalog.picks`. Miss either and the
    /// evaluation runs on the spec default rather than on what was saved.
    ///
    /// T-44 added a third: the steroid ORAL trio (`dose`/`tab`/`split`) are web input
    /// strings and iOS numbers named `oralDose`/`tabMg`/`oralSplit`.
    static func values(fromConfig config: JSONValue, slug: CalculatorSlug) -> CalculatorValues {
        let spec = spec(for: slug)
        var v = CalculatorValues.defaults(for: spec.fields)
        for field in spec.fields {
            guard let raw = config[field.key] else { continue }
            switch field.kind {
            case .number, .picker, .segmented, .stepperDays:
                if let d = raw.double { v.numbers[field.key] = d }
            // `.modePicker` belongs on the STRING branch, and getting it here matters
            // more than it looks: this is the path that restores a saved protocol
            // into the form. Left off, a TRT row saved in `ndays` would reopen in
            // whatever the spec defaults to and recompute a different per-injection
            // dose from the same stored config.
            case .stringPicker, .modePicker:
                if let s = raw.string { v.strings[field.key] = s }
            case .toggle:
                if let b = raw.bool { v.bools[field.key] = b }
            }
        }
        switch slug {
        case .peptide:
            if let unit = config["doseUnit"]?.string {
                v.numbers["doseUnitMcg"] = unit.lowercased() == "mcg" ? 1 : 0
            }
        case .steroid:
            // `slug` AND `esterKey` together name one picker entry (T-44). Matching on
            // the slug alone is what forced every Trenbolone row onto Acetate.
            if let key = config["slug"]?.string,
               let idx = SteroidCatalog.pickIndex(compoundKey: key,
                                                  esterKey: config["esterKey"]?.string) {
                v.numbers["compound"] = Double(idx)
            }
            // The oral trio are STRINGS on the web and NUMBERS under other names here,
            // so the loop above cannot see them either. An unparseable or absent value
            // leaves the spec default standing rather than writing 0 — a 0 tablet
            // strength is the one input `steroidOral` treats as invalid.
            if let d = config["dose"]?.string.flatMap({ Double($0) }) { v.numbers["oralDose"] = d }
            if let t = config["tab"]?.string.flatMap({ Double($0) }) { v.numbers["tabMg"] = t }
            if let s = config["split"]?.string.flatMap({ Double($0) }) { v.numbers["oralSplit"] = s }
        default:
            break
        }
        return v
    }

    static func spec(for slug: CalculatorSlug) -> CalculatorSpec {
        switch slug {

        case .trt:
            // config keys mirror web: strength, mgWeek, injPerWeek, mode, nDays,
            // mlDrawn, esterType, syringeMl.
            //
            // ── T-01a #1: `mode` IS A FIELD NOW, NOT AN EXTRA ────────────────────
            // It was a hardcoded `"perweek"` in configExtras: every iOS TRT save
            // carried a mode the user could not see, could not change, and had not
            // chosen. The web leads this page with a three-way switch and defaults it
            // to `ndays` (`app.js:8246`, `useState('ndays')`).
            //
            // THE KEY SET IS UNCHANGED and that is the point. `mode`, `nDays` and
            // `mlDrawn` move from configExtras to real fields carrying the SAME names
            // and the SAME types, so `configJSON()` emits the same eight keys it
            // always did. The unique index covers the whole config, so a key set that
            // drifted by one would make every iOS save a different protocol from the
            // equivalent web row instead of the same one.
            //
            // THE DEFAULT MOVES, deliberately: `perweek` → `ndays`. That is a real
            // change to what an untouched save writes, and it is the correct one —
            // it is the web's default, so an iOS save and a web save from untouched
            // defaults now agree where before they disagreed. Recorded in TASKS.md
            // under T-01a rather than slipped in.
            return CalculatorSpec(slug: slug, savedType: "trt", saveTitle: "TRT Dose", fields: [
                .modePicker("mode", "Mode", options: trtModeOptions, default: "ndays"),
                .number("strength", "Vial strength", unit: "mg/mL", default: 200, range: 1...500, step: 1,
                        drum: TickDrum.vialStrength),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 100, range: 0...1000, step: 10,
                        quick: [100, 200, 300, 400, 500], drum: TickDrum.weeklyDose),
                // `ndays` mode only. Web default 3.5 — twice-weekly, the commonest
                // TRT interval, and a legal non-integer (`EVERY_N_DAYS_VALUES`).
                .number("nDays", "Every N days", unit: "days", default: 3.5, range: 0.5...14, step: 0.5,
                        drum: TickDrum.everyNDays),
                // `perweek` mode only.
                .picker("injPerWeek", "Frequency", options: trtFreqOptions, default: 2),
                // `ml2mg` mode only — the reverse calculation: you drew this much,
                // what dose was it?
                .number("mlDrawn", "Volume drawn", unit: "mL", default: 0.5, range: 0...3, step: 0.05,
                        drum: TickDrum.mlDrawn),
                .stringPicker("esterType", "Ester", options: CalcConst.esterTypes, default: "Testosterone Enanthate"),
                .segmented("syringeMl", "Syringe barrel",
                           options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .eod:
            return CalculatorSpec(slug: slug, savedType: "eod", saveTitle: "TRT & EOD", fields: [
                .number("strength", "Vial strength", unit: "mg/mL", default: 200, range: 1...500, step: 1),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 70, range: 0...1000, step: 10,
                        help: "Hardcoded every-other-day interval (3.5 injections/week).",
                        quick: [70, 100, 150, 200, 250]),
                .stringPicker("esterType", "Ester", options: CalcConst.esterTypes, default: "Testosterone Enanthate"),
                .segmented("syringeMl", "Syringe barrel",
                           options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .microdose:
            // micro defaults to small strength + every-N-days mode.
            return CalculatorSpec(slug: slug, savedType: "microdose", saveTitle: "TRT Microdose", fields: [
                .number("strength", "Vial strength", unit: "mg/mL", default: 10, range: 1...100, step: 1),
                .number("mgWeek", "Weekly dose", unit: "mg/week", default: 5, range: 0...100, step: 0.5,
                        quick: [5, 10, 15, 20, 25]),
                .number("nDays", "Inject every", unit: "days", default: 3, range: 1...7, step: 1),
                .segmented("syringeMl", "Syringe barrel",
                           options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .hcg:
            return CalculatorSpec(slug: slug, savedType: "hcg", saveTitle: "HCG", fields: [
                .number("vialIU", "Vial size", unit: "IU", default: 5000, range: 0...20000, step: 100),
                .number("bacWaterMl", "Bac water", unit: "mL", default: 1, range: 0...10, step: 0.5),
                .number("dose", "Dose per injection", unit: "IU", default: 250, range: 0...5000, step: 50,
                        quick: [250, 500, 1000, 1500, 2000]),
                .segmented("syringeMl", "Syringe barrel",
                           options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .peptide:
            return CalculatorSpec(slug: slug, savedType: "peptide", saveTitle: "Peptide", fields: [
                .number("peptideMg", "Peptide in vial", unit: "mg", default: 50, range: 0...100, step: 1),
                .number("bawMl", "Bac water", unit: "mL", default: 10, range: 0...30, step: 0.5),
                // T-41 — THE DOSE IS DECLARED IN mcg AND SCALES WITH `doseUnitMcg`.
                //
                // `unitScaling` is the whole fix and `UnitScaling`'s own comment carries
                // the reasoning. What is declared HERE is the numbers, and each of the
                // four moved:
                //
                //   unit: was nil, so the field showed a bare number while a separate
                //     picker named the unit somewhere else on the row. The web's dose
                //     field carries the suffix AND the toggle (`QuickPickerField`
                //     `unit: doseUnit` beside a `DrumUnitToggle`), and on a screen whose
                //     defect was "500 means two different doses" the suffix is not
                //     decoration — it is what makes the photograph readable.
                //
                //   range: was 0...10000 IN BOTH UNITS. The web's mcg ceiling is 20000
                //     (`doseMax`), so the base moves 10000 → 20000 for parity and mg
                //     becomes 0...20 — which is the number that matters, since the old
                //     ceiling let mg run to 10000, i.e. 10 grams of peptide.
                //
                //   THE LOWER BOUND STAYS 0 AND THE WEB'S IS 1 mcg / 0.001 mg. A
                //     DELIBERATE DIVERGENCE, recorded rather than slipped in: the web
                //     clamps on BLUR (`commitDose`), iOS clamps on EVERY KEYSTROKE
                //     (`NumberField.onChange(of: text)`). With a floor of 0.001 in mg,
                //     typing `0.5` clamps the leading `0` up to `0.001`, rewrites the
                //     text, and the remaining keystrokes land on it — `0.0015`. A
                //     non-zero floor is safe on blur and hostile per keystroke, and 0 is
                //     what every other dose field in this app already uses for the
                //     not-yet-finished state.
                //
                //   step: was 50 in both units; the web's is 1 mcg / 0.001 mg. It is
                //     inert today — nothing reads `step` since the ± pair was replaced
                //     by `TickDrum` — but a spec that states a wrong number is a trap
                //     for whoever wires it up next, so it is the web's and it scales.
                //
                //   quick: unchanged in mcg, and `250 · 500 · 750 · 1000 · 2000` divided
                //     by 1000 in mg, which is exactly what the web does to its own
                //     drum values (`DOSE_PEP_MCG_VALUES.map(v => v / 1000)`).
                .number("dosePerInj", "Dose per injection", unit: "mcg",
                        default: 500, range: 0...20000, step: 1,
                        quick: [250, 500, 750, 1000, 2000],
                        unitScaling: .init(selectorKey: "doseUnitMcg", baseSelectorValue: 1,
                                           alternateUnit: "mg", factor: 1000,
                                           baseDecimals: 0, alternateDecimals: 3)),
                .picker("doseUnitMcg", "Dose unit", options: [
                    .init(label: "mcg", value: 1), .init(label: "mg", value: 0),
                ], default: 1),
                .number("injPerWeek", "Injections/week", unit: "×", default: 1, range: 1...14, step: 1),
                .segmented("syringeMl", "Syringe barrel",
                           options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .reconstitution:
            return CalculatorSpec(slug: slug, savedType: "reconstitution", saveTitle: "Reconstitution", fields: [
                .number("peptideMg", "Peptide in vial", unit: "mg", default: 5, range: 0...100, step: 1),
                .number("targetConc", "Target concentration", unit: "mcg/mL", default: 1000, range: 0...10000, step: 50),
            ])

        // ── THE THREE GLP-1 CALCULATORS  (T-45) ──────────────────────────────
        //
        // `conc` and `dose` WERE `.picker` — a closed SwiftUI `Menu`, so the option
        // array WAS the complete set of values the app could express — over arrays
        // truncated to 12 / 11 / 7 / 16 entries. Two defects stacked on one control:
        // the list was short, and the list was also the ceiling.
        //
        // They are `.number` now: typed entry, clamped to the array's own bounds,
        // with the full web array spent as `drum:` — the ruler `TickDrum` was written
        // for, whose doc comment already states the rule this change needs
        // ("a TYPED value need not be on a tick … snapping the user's typed dose to
        // the nearest 5 would be the calculator editing the number the user acts on").
        //
        // WHY TYPED ENTRY IS REQUIRED HERE AND NOT A NICETY. The web's control on
        // both `master`/deployed and `feature/dosage-status-model` accepts a typed
        // value off the list — deployed `ConcDrumField` takes any positive number
        // rounded to 2 dp, the branch's `QuickPickerField` clamps it to the array
        // bounds. Concentration is the field that decides the DIVISOR of every dose
        // on this screen, and compounded vials do not come on a preset ladder: the
        // page's own FAQ names 12 mg/mL as a strength compounders produce, and 12 is
        // not in `GLP1_CONC_VALUES`. With a closed menu a 25 mg/mL vial had no
        // correct option at all — the nearest was 20, and `glp1(conc: 20, dose:)`
        // returns a draw 25 % larger than the true one on a screen that looks
        // entirely normal. Lengthening the list alone would not have fixed that:
        // any value BETWEEN two entries stays unreachable, so the ladder can only
        // ever be the shortcut and never the only way in.
        //
        // RANGES are the arrays' own first/last, which is the branch's clamp exactly.
        // The deployed build imposes no upper bound on `conc`; 60 mg/mL is already
        // multiples of any real GLP-1 vial, and iOS's clamp REWRITES THE VISIBLE TEXT
        // when it bites, so a refused value is seen rather than silently absorbed.
        // Recorded in TASKS.md rather than quietly widened.
        //
        // DEFAULTS ARE UNTOUCHED (5 / 7.5 / 5 and 0.5 / 5 / 1). The web opens these
        // fields blank and that difference is SH-5's, filed separately — changing it
        // here would alter what an untouched save writes, which is a config change
        // wearing a layout change's clothes.
        case .semaglutide:
            return CalculatorSpec(slug: slug, savedType: "semaglutide", saveTitle: "Semaglutide", fields: [
                .number("conc", "Concentration", unit: "mg/mL", default: 5, range: 0...60, step: 0.5,
                        help: "mg/mL after reconstitution. Type the strength printed on your vial.",
                        drum: CalcConst.glp1Concs),
                .number("dose", "Dose", unit: "mg", default: 0.5, range: 0...7.5, step: 0.25,
                        help: "mg per weekly injection.",
                        drum: CalcConst.semaDoses),
                .segmented("syringeMl", "Syringe barrel",
                           options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .tirzepatide:
            return CalculatorSpec(slug: slug, savedType: "tirzepatide", saveTitle: "Tirzepatide", fields: [
                .number("conc", "Concentration", unit: "mg/mL", default: 7.5, range: 0...60, step: 0.5,
                        help: "mg/mL after reconstitution. Type the strength printed on your vial.",
                        drum: CalcConst.glp1Concs),
                .number("dose", "Dose", unit: "mg", default: 5, range: 0...40, step: 2.5,
                        help: "mg per weekly injection.",
                        drum: CalcConst.tirzDoses),
                .segmented("syringeMl", "Syringe barrel",
                           options: barrelOptions, default: defaultBarrel(for: slug)),
            ])

        case .retatrutide:
            return CalculatorSpec(slug: slug, savedType: "retatrutide", saveTitle: "Retatrutide", fields: [
                .number("conc", "Concentration", unit: "mg/mL", default: 5, range: 0...60, step: 0.5,
                        help: "mg/mL after reconstitution. Type the strength printed on your vial.",
                        drum: CalcConst.glp1Concs),
                .number("dose", "Dose", unit: "mg", default: 1, range: 0...24, step: 0.5,
                        help: "mg per weekly injection.",
                        drum: CalcConst.retaDoses),
                .segmented("syringeMl", "Syringe barrel",
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
                .number("dose", "Dose per injection", unit: "mcg", default: 250, range: 0...5000, step: 50,
                        quick: [200, 250, 500, 750, 1000]),
                .segmented("syringeMl", "Syringe barrel",
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
                .segmented("syringeMl", "Syringe barrel",
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
            // T-43 — THE TT VALUE IS READ IN THE UNIT `ttUnitNgdl` SELECTS, so the field
            // carries a `unitScaling` and the flip converts it. This is T-41's defect on a
            // second screen: `UnitScaling` in CalculatorModels is the mechanism, and this
            // is a declaration on top of it rather than a new one.
            //
            // WHAT IT DID: the picker changed the unit and left the number, so the shipped
            // default — 20 with SHBG 50 — went from FAI 40.0 "Normal" to 1.4 "Low" with no
            // blood value changed. The web converts, and its own source names the exact
            // consequence (`FreeTestPage.changeTtUnit`, `public/app.js:8434-8443` on
            // `feature/dosage-status-model`, read from the checkout rather than from a
            // document about it. The citation is corrected: this was first written as
            // 7878-7887, which is the Reverse Dose Solver. The QUOTED CODE was verbatim
            // right and only the line number was wrong — which is the more dangerous of
            // the two, because a wrong reference that points at real-looking code is
            // read as corroboration by the next person. A second, identical copy lives
            // at :8595 for the FTV page, which iOS does not have):
            //
            //   // Toggling the unit converts the typed value so the physical quantity is
            //   // kept (600 ng/dL -> ~20.8 nmol/L, not read as 600 nmol/L -> a 28.84x
            //   // wrong FAI/band).
            //   const nmol = ttUnit === 'ngdl' ? cur / 28.84 : cur;
            //   const conv = u === 'ngdl' ? nmol * 28.84 : nmol;
            //   setTtRaw(String(Math.round(conv * 100) / 100));
            //
            // BASE IS nmol/L, because that is the unit the field's default (20) is already
            // in and the unit the maths is defined in — `CalculatorEngine.freeTestIndex`
            // converts ng/dL INTO nmol/L before dividing by SHBG, and FAI is (TT ÷ SHBG)
            // × 100 with BOTH terms in nmol/L. `factor` is declared as "base units per
            // alternate unit", and one ng/dL is 1/28.84 nmol/L, so it is the RECIPROCAL of
            // the engine's constant, not the constant. `toAlternate` therefore multiplies
            // by 28.84 and `toBase` divides — `changeTtUnit`, both ways round.
            //
            // DECIMALS ARE THE WEB'S, verbatim: `Math.round(conv * 100) / 100` is two
            // decimals in BOTH units.
            //
            //   THE ROUND TRIP IS EXACT ONE WAY ONLY, and that is a property of the number
            //   28.84 rather than of this code. nmol/L → ng/dL → nmol/L returns the
            //   original for EVERY two-decimal value: the ng/dL rounding is worth at most
            //   0.005 ng/dL, i.e. 0.00017 nmol/L, far inside the nmol hundredth it lands
            //   back on. The other direction cannot be exact, because 0.005 nmol/L is
            //   0.144 ng/dL — WIDER than the ng/dL hundredth — so 600 ng/dL returns as
            //   599.87. Exactness both ways needs the two decimal grids to correspond
            //   under the factor; they do for T-41's 1000 (1 mcg IS 0.001 mg) and no
            //   decimal pair can for 28.84. Buying the ng/dL trip would cost the nmol one
            //   (four base decimals puts "20.7999" in a field the user typed 20.8 into).
            //   What is kept instead is 0.024% at 600 ng/dL — three orders of magnitude
            //   under any testosterone assay's precision, and invisible in an FAI printed
            //   to one decimal. Both directions are pinned in `FreeTestUnitTests`.
            //
            // RANGE — IT WAS ONE RANGE HELD IN BOTH UNITS, the same second half T-41 had.
            // `0...2000` is a ng/dL ceiling (a lab-report figure); read as nmol/L it
            // admits 2000 nmol/L, an FAI of 4000. It is now 0...100 nmol/L, which resolves
            // to 0...2884 ng/dL — clear of any real assay result including a
            // supraphysiological peak, and the two ends are images of each other, so
            // nothing in range on one side is out of range on the other.
            //
            // THE FLOOR STAYS 0, for the reason recorded on the peptide dose: iOS clamps
            // on every keystroke, so a non-zero floor rewrites the leading "0" of a
            // part-typed value.
            //
            // THE SUFFIX IS NEW. The field declared no unit at all, so the number's unit
            // lived only in a separate picker — on the one screen whose defect is that the
            // same number means two different blood values.
            return CalculatorSpec(slug: slug, savedType: "freetest", saveTitle: "Free T Index", fields: [
                .number("tt", "Total testosterone", unit: "nmol/L",
                        default: 20, range: 0...100, step: 0.1,
                        unitScaling: .init(selectorKey: "ttUnitNgdl", baseSelectorValue: 0,
                                           alternateUnit: "ng/dL", factor: 1.0 / 28.84,
                                           baseDecimals: 2, alternateDecimals: 2)),
                .picker("ttUnitNgdl", "TT unit", options: [
                    .init(label: "nmol/L", value: 0), .init(label: "ng/dL", value: 1),
                ], default: 0),
                .number("shbg", "SHBG", unit: "nmol/L", default: 50, range: 0...250, step: 1),
            ])

        case .cyclePlotter:
            // Bespoke screen — no generic fields.
            return CalculatorSpec(slug: slug, savedType: "plotter", saveTitle: "Cycle Plotter", fields: [])

        case .steroid:
            // ── T-44 — BOTH FORMS, AND THE ESTER IS IN THE COMPOUND LIST ──────────
            //
            // THE COMMENT THAT USED TO BE HERE SAID ORALS WERE "HELD BACK". They were
            // not. It claimed the oral path was withheld "rather than shipped showing
            // syringe fields that mean nothing for a tablet", and that is precisely
            // what shipped: the picker enumerated all twelve compounds, five of them
            // oral-only, and the screen opened on Oxandrolone (Anavar) offering a
            // 200 mg/mL vial strength and a syringe barrel. `evaluate` returned
            // **0.75 mL / 75 units for a tablet**. `SteroidCompound.canInject` was
            // correct the whole time and nothing read it.
            //
            // The web does not have one screen with a toggle — it has one PAGE PER
            // COMPOUND, and each page decides its own form from the compound's `cls`:
            // `useState(canInject ? 'injectable' : 'oral')` (`app.js:8789`). iOS has
            // one screen and a picker, so the same decision is made per SELECTION and
            // `CalculatorScreen.shouldShow` renders the matching half. Both halves are
            // declared here; neither is ever shown at the same time as the other.
            //
            // WHAT THE WEB ASKS AN ORAL FOR — `app.js:8964-8968`, three plain inputs:
            // "Daily dose (mg)", "Tablet strength (mg/tab)", "Doses per day". No vial
            // strength, no weekly dose, no interval, NO SYRINGE — `syringeSize` and
            // the whole `SyringeResultPanel` are `isInject ? … : null` (8988, 8979),
            // and so is the "Active <parent>" line (8984), which is why an oral shows
            // no ester arithmetic either.
            //
            // `compound` is an index into `SteroidCatalog.picks` — the ESTER-EXPANDED
            // list, which is what the web's dropdown is (`app.js:8927-8932`) — rather
            // than into `.all`. `configExtras` splits it back into the web's `slug`
            // and `esterKey`, so the SAVED KEY SET IS UNCHANGED.
            //
            // The oral defaults are the web's, as closely as a Double can hold them:
            // `dose` opens EMPTY (`useState('')`, 8810) and 0 is this control's own
            // empty reading, so the screen invents no dose — the web page is explicit
            // that this calculator is "Maths + pharmacokinetic timing only — no doses,
            // cycles, or regimens" (8745-8746). `tab` is the web's `defTab` fallback
            // of 10 (8798); the web makes it PER COMPOUND (Anadrol ships 50 mg tabs),
            // which needs the value to follow the picker and is reported, not guessed
            // at here. `split` is 1 (8812).
            return CalculatorSpec(slug: slug, savedType: "steroid", saveTitle: "Steroid Dosage", fields: [
                .picker("compound", "Compound",
                        options: SteroidCatalog.picks.enumerated().map { idx, p in
                            .init(label: p.label, value: Double(idx))
                        },
                        default: 0),
                // ── injectable form (`cls` contains 'injectable') ──
                .number("strength", "Vial strength", unit: "mg/mL", default: 200, range: 0...500, step: 5),
                .number("mgWeek", "Weekly dose", unit: "mg", default: 300, range: 0...2000, step: 10,
                        quick: [200, 300, 400, 500, 600]),
                .number("nDays", "Inject every", unit: "days", default: 3.5, range: 0.5...14, step: 0.5),
                .segmented("syringeMl", "Syringe barrel",
                           options: barrelOptions, default: defaultBarrel(for: slug)),
                // ── oral form (`cls:'oral'`) ──
                .number("oralDose", "Daily dose", unit: "mg", default: 0, range: 0...500, step: 1),
                .number("tabMg", "Tablet strength", unit: "mg/tab", default: 10, range: 0...200, step: 1),
                .number("oralSplit", "Doses per day", default: 1, range: 1...6, step: 1),
            ])
        }
    }
}
