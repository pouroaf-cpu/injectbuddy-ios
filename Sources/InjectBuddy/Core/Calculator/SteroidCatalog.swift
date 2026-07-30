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
    /// Order matches the web hub.
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
}
