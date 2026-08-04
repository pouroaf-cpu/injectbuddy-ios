import Foundation

// ─── SteroidCatalog ──────────────────────────────────────────────────────────
// The 12 compounds behind the Steroid Dosage calculator, transcribed from
// IB_STEROIDS in Injectbuddy/public/app.js (the web's /steroid-dosage-calculator/
// hub and its 9 published spokes read the same table).
//
// Only the fields the DOSE MATHS needs are carried across — class, ester variants,
// esterFactor, and the default concentration / tablet strength. Half-life quality
// flags, copy and SEO metadata stay on the web; they do not affect a number.
//
// `esterFactor` is the active-hormone fraction by mass: an ester adds weight that is
// not hormone, so 200mg of Deca is 0.64 × 200 = 128mg of actual nandrolone. The web
// surfaces this as "active weekly", and it is the one steroid-specific quantity that
// TRT does not already compute.
//
// Compound half-lives live in the web repo's spec/compounds.json, generated from
// pk.js — a DIFFERENT table, used by the cycle plotter. Do not conflate them.

struct SteroidEster: Identifiable, Hashable {
    let key: String
    let label: String
    let esterFactor: Double
    let defaultConc: Double

    var id: String { key }
}

struct SteroidCompound: Identifiable, Hashable {
    let key: String
    let displayName: String
    let canInject: Bool
    let canOral: Bool
    /// Nil when the compound has ester variants — read the chosen ester's instead.
    let esterFactor: Double?
    /// mg/mL default for the vial-strength field.
    let defaultConc: Double?
    /// mg per tablet default for the oral field.
    let defaultTab: Double?
    let esters: [SteroidEster]

    var id: String { key }

    /// The ester the UI starts on, if this compound has any.
    var defaultEster: SteroidEster? { esters.first }

    func esterFactor(for ester: SteroidEster?) -> Double {
        ester?.esterFactor ?? esterFactor ?? 1
    }

    func defaultConc(for ester: SteroidEster?) -> Double {
        ester?.defaultConc ?? defaultConc ?? 200
    }
}

enum SteroidCatalog {
    /// Order matches the `IB_STEROIDS` object literal (`app.js:8748-8761`), which is
    /// NOT the order the web's dropdown uses — that is `IB_STEROID_ORDER`
    /// (`app.js:8762`), a different sequence starting at `trenbolone`. See `picks`.
    static let all: [SteroidCompound] = [
        SteroidCompound(key: "anavar", displayName: "Oxandrolone (Anavar)",
                        canInject: false, canOral: true,
                        esterFactor: 1, defaultConc: nil, defaultTab: 10, esters: []),
        SteroidCompound(key: "trenbolone", displayName: "Trenbolone",
                        canInject: true, canOral: false,
                        esterFactor: nil, defaultConc: nil, defaultTab: nil,
                        esters: [
                            SteroidEster(key: "acetate",   label: "Acetate",   esterFactor: 0.87, defaultConc: 100),
                            SteroidEster(key: "enanthate", label: "Enanthate", esterFactor: 0.71, defaultConc: 200),
                        ]),
        SteroidCompound(key: "dianabol", displayName: "Dianabol (Metandienone)",
                        canInject: false, canOral: true,
                        esterFactor: 1, defaultConc: nil, defaultTab: 10, esters: []),
        SteroidCompound(key: "npp", displayName: "Nandrolone Phenylpropionate (NPP)",
                        canInject: true, canOral: false,
                        esterFactor: 0.67, defaultConc: 100, defaultTab: nil, esters: []),
        SteroidCompound(key: "tbol", displayName: "Turinabol (Tbol)",
                        canInject: false, canOral: true,
                        esterFactor: 1, defaultConc: nil, defaultTab: 10, esters: []),
        SteroidCompound(key: "deca", displayName: "Deca (Nandrolone Decanoate)",
                        canInject: true, canOral: false,
                        esterFactor: 0.64, defaultConc: 200, defaultTab: nil, esters: []),
        // The only compound the web marks as both — "oral|injectable".
        SteroidCompound(key: "winstrol", displayName: "Winstrol (Stanozolol)",
                        canInject: true, canOral: true,
                        esterFactor: 1, defaultConc: 50, defaultTab: 10, esters: []),
        SteroidCompound(key: "equipoise", displayName: "Equipoise (Boldenone Undecylenate)",
                        canInject: true, canOral: false,
                        esterFactor: 0.63, defaultConc: 250, defaultTab: nil, esters: []),
        SteroidCompound(key: "anadrol", displayName: "Anadrol (Oxymetholone)",
                        canInject: false, canOral: true,
                        esterFactor: 1, defaultConc: nil, defaultTab: 50, esters: []),
        SteroidCompound(key: "masteron", displayName: "Masteron (Drostanolone)",
                        canInject: true, canOral: false,
                        esterFactor: nil, defaultConc: nil, defaultTab: nil,
                        esters: [
                            SteroidEster(key: "propionate", label: "Propionate", esterFactor: 0.84, defaultConc: 100),
                            SteroidEster(key: "enanthate",  label: "Enanthate",  esterFactor: 0.73, defaultConc: 200),
                        ]),
        SteroidCompound(key: "primobolan", displayName: "Primobolan (Methenolone Enanthate)",
                        canInject: true, canOral: false,
                        esterFactor: 0.73, defaultConc: 100, defaultTab: nil, esters: []),
        SteroidCompound(key: "superdrol", displayName: "Superdrol (Methasterone)",
                        canInject: false, canOral: true,
                        esterFactor: 1, defaultConc: nil, defaultTab: 10, esters: []),
    ]

    static func compound(key: String) -> SteroidCompound? {
        all.first { $0.key == key }
    }

    // ─── The picker's own list  (T-44) ───────────────────────────────────────
    //
    // `all` is the COMPOUND table. It is not the list of things a user can pick,
    // and treating it as one is half of T-44: the picker enumerated `all`, so a
    // compound with esters could only ever be evaluated on `esters.first`.
    // Trenbolone's first ester is Acetate (0.87), so 300 mg/week of Tren E read
    // **261 mg active instead of 213 mg — 22.5 % high** with no control anywhere
    // on the screen to correct it.
    //
    // THE WEB DOES NOT HAVE AN ESTER PICKER EITHER, and that is the point. Its
    // compound dropdown is built by walking the compound order and pushing ONE
    // OPTION PER ESTER — `public/app.js:8927-8932` on `feature/dosage-status-model`:
    //
    //     if (sd.esters) { var brand = sd.displayName.split(' (')[0];
    //       Object.keys(sd.esters).forEach(function (k) {
    //         compoundOptions.push({ label: brand + ' ' + sd.esters[k].label,
    //                                value: s + '|' + k }); }); }
    //     else { compoundOptions.push({ label: sd.displayName, value: s }); }
    //
    // with its own comment above it: *"ester compounds expand to one entry per
    // ester (e.g. "Trenbolone Acetate" / "Trenbolone Enanthate"); there is no
    // separate ester picker."* So the ester is chosen by choosing the compound,
    // and the config still carries the two apart (`slug` + `esterKey`).
    //
    // ORDER IS iOS's EXISTING ORDER, DELIBERATELY NOT THE WEB'S. The web walks
    // `IB_STEROID_ORDER` (`app.js:8762`), which starts at `trenbolone`; iOS walks
    // the `IB_STEROIDS` object key order, which starts at `anavar`. That is a real
    // second difference — it decides which compound the screen OPENS on — but it
    // moves the shipped default and therefore what an untouched save writes, so it
    // is reported rather than taken here.

    /// One row of the compound picker: a compound, plus which ester of it, where the
    /// compound has any. The unit the screen and the engine actually select.
    struct SteroidPick: Identifiable, Hashable {
        let compound: SteroidCompound
        let ester: SteroidEster?

        /// `slug|esterKey`, the web's own option value (`app.js:8930`).
        var id: String { ester.map { "\(compound.key)|\($0.key)" } ?? compound.key }

        /// The web's label rule, verbatim: brand + ester for an ester entry, the
        /// full display name otherwise. "Brand" is the display name up to the first
        /// parenthesis — `displayName.split(' (')[0]` — so
        /// "Masteron (Drostanolone)" + "Enanthate" is "Masteron Enanthate", not
        /// "Masteron (Drostanolone) Enanthate".
        var label: String {
            guard let ester else { return compound.displayName }
            let brand = compound.displayName.components(separatedBy: " (")[0]
            return "\(brand) \(ester.label)"
        }

        /// Active-hormone mass fraction for THIS entry — the number T-44 is about.
        var esterFactor: Double { compound.esterFactor(for: ester) }

        /// mg/mL this entry's vial is usually sold at.
        var defaultConc: Double { compound.defaultConc(for: ester) }

        /// Whether this entry has an injectable form at all. `cls` on the web:
        /// `'oral'`, `'injectable'`, or `'oral|injectable'` (Winstrol only).
        var canInject: Bool { compound.canInject }
    }

    /// Every entry the compound picker offers, esters expanded — the iOS analogue of
    /// the web's `compoundOptions`. 14 rows from 12 compounds: Trenbolone and Masteron
    /// each contribute two.
    static let picks: [SteroidPick] = all.flatMap { c -> [SteroidPick] in
        c.esters.isEmpty
            ? [SteroidPick(compound: c, ester: nil)]
            : c.esters.map { SteroidPick(compound: c, ester: $0) }
    }

    /// The entry at `index`, falling back to the first rather than returning nil.
    ///
    /// The picker field stores a Double index, and an index can arrive from a saved
    /// config written by a build with a different list. Falling back renders an
    /// honest screen for a real compound; returning nil would blank a dosing screen.
    static func pick(at index: Int) -> SteroidPick {
        picks.indices.contains(index) ? picks[index] : picks[0]
    }

    /// The index of the entry a saved config names, or nil when the compound is not
    /// one this build knows.
    ///
    /// `esterKey` is matched where the compound has esters; an absent or unknown
    /// ester falls back to that compound's FIRST entry, which is what a config
    /// written before the expansion carries.
    static func pickIndex(compoundKey: String, esterKey: String?) -> Int? {
        if let key = esterKey, !key.isEmpty,
           let exact = picks.firstIndex(where: { $0.compound.key == compoundKey
                                              && $0.ester?.key == key }) {
            return exact
        }
        return picks.firstIndex { $0.compound.key == compoundKey }
    }

    /// Whether the steroid form asks for `fieldKey` when picker entry `index` is
    /// selected — the T-44 rule, in the CATALOG rather than in the view.
    ///
    /// It lives here and not in `CalculatorScreen` because it decides whether a
    /// dosing input is offered at all, and a rule that only a SwiftUI `View` can
    /// state is a rule no unit test can reach. `CalculatorScreen.shouldShow`
    /// delegates to it; the tests assert it directly.
    ///
    /// The web splits the same two sets at `app.js:8951-8968` — `injectInputs`
    /// (mode tab, `VialStrengthCard`, `WeeklyDoseField`, `EveryNDaysField`) against
    /// `oralInputs` (daily dose, tablet strength, doses per day) — and picks between
    /// them with `var inputs = isInject ? injectInputs : oralInputs` (8969). The
    /// syringe barrel is not in either list because it is a separate `isInject ? … :
    /// null` on the result side (8988).
    ///
    /// A key it does not recognise is SHOWN. The steroid spec is not the only thing
    /// that may add a field, and a field silently swallowed by a default of `false`
    /// is exactly the "correct code that nothing calls" shape T-47 is about.
    static func showsField(_ fieldKey: String, forPickAt index: Int) -> Bool {
        let injectable = pick(at: index).canInject
        switch fieldKey {
        case "strength", "mgWeek", "nDays", "syringeMl": return injectable
        case "oralDose", "tabMg", "oralSplit":           return !injectable
        default:                                         return true
        }
    }

    /// A number as the STRING a web `<input type="number">` would be holding.
    ///
    /// The steroid config's oral trio — `dose`, `tab`, `split` — are the raw input
    /// STATE on the web (`app.js:8810-8812`) and are therefore strings in the saved
    /// config, not numbers. The database de-duplicates on the whole config, so
    /// `"50"` and `50` are two different protocols; this is what keeps an iOS oral
    /// save the same shape as the web's.
    static func inputString(_ v: Double) -> String {
        guard v.isFinite else { return "" }
        if v == v.rounded() && abs(v) < 1e15 { return String(Int(v)) }
        return String(format: "%g", v)
    }
}
