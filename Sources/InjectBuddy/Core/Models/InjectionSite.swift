import Foundation

// ─── Injection sites ─────────────────────────────────────────────────────────
// THE vocabulary for `dose_log.site`, and the rotation that suggests the next one.
//
// **These strings are a shared contract with the web app, not display text.** The web
// stores the human label in the column (`lib/site-rotation.ts`: "dose_log.site holds the
// human label, e.g. 'L Glute'") and reads it straight back with
// `p.sites.indexOf(pin.site)` (`components/account/dashboard/DashboardContext.tsx`) to
// place the dose on the body map and colour the muscle. A label that is not IN the
// track resolves to index −1 and is DISCARDED — so "Left glute", "L. Glute" or
// "left-glute" are all exactly as useless to the rotation model as the NULL iOS used to
// write, while looking correct in the database.
//
// Copied verbatim from `lib/account-schedule.ts` SITES_IM / SITES_SUBQ, which
// `lib/body-regions.ts` in turn pins the body-map artwork to ("The labels must match
// lib/account-schedule.ts's SITES_IM / SITES_SUBQ exactly"). Order matters as well as
// spelling: the rotation steps through the array, so the sequence a user walks is the
// array's own.

/// How a protocol is administered. Drives WHICH site track applies — the web's
/// `DerivedProtocol.route`.
enum InjectionRoute: String {
    case intramuscular = "IM"
    case subcutaneous  = "SubQ"
    case oral          = "Oral"

    /// Section header for the picker. Small caps, like every other eyebrow in the app.
    var trackTitle: String {
        switch self {
        case .intramuscular: return "Intramuscular sites"
        case .subcutaneous:  return "Subcutaneous sites"
        case .oral:          return "No injection site"
        }
    }
}

enum InjectionSite {

    /// Eight IM sites, in the web's order.
    static let imTrack = ["L Glute", "R Glute", "L VG", "R VG",
                          "L Quad", "R Quad", "L Delt", "R Delt"]

    /// Six SubQ sites, in the web's order.
    static let subQTrack = ["Abdomen L", "Abdomen R", "L Love handle",
                            "R Love handle", "L Thigh", "R Thigh"]

    /// Every label the column may legitimately hold. Used by the round-trip test to
    /// prove nothing outside the web's vocabulary can be written.
    static let allKnown = imTrack + subQTrack

    /// The route a saved protocol is administered by — mirrors the web's `deriveDose`
    /// (`lib/account-schedule.ts`), branch for branch.
    ///
    /// Returns nil for a calculator that has no injection schedule at all, which is the
    /// web's `NON_SCHEDULABLE` set plus the plotter: those rows never reach a log flow,
    /// and inventing a site for one would put a body location on a BMI calculation.
    static func route(for dosage: SavedDosage) -> InjectionRoute? {
        guard let slug = CalculatorSlug(rawValue: dosage.calculatorType) else { return nil }
        switch slug {
        case .trt, .eod:
            return .intramuscular
        case .steroid:
            // The web reads `cfg.form`, defaulting to injectable, and gives the oral
            // branch `sites: []`. A tablet has no site and must not be offered one.
            return (dosage.config["form"]?.string == "oral") ? .oral : .intramuscular
        case .microdose:
            // NOT in the web's `deriveDose` — a microdose row is dropped there entirely
            // (see TASKS T-06). It is a TRT protocol by every other measure, so it takes
            // the IM track here rather than losing its site as well as its schedule.
            return .intramuscular
        case .peptide, .semaglutide, .tirzepatide, .retatrutide, .bpc157, .bpc157blend, .hcg:
            return .subcutaneous
        case .reconstitution, .bmi, .freeTestIndex, .cyclePlotter:
            return nil
        }
    }

    /// The sites offered for a protocol. Empty when there is nothing to offer — an oral
    /// row, or a calculator with no schedule.
    static func track(for dosage: SavedDosage) -> [String] {
        switch route(for: dosage) {
        case .intramuscular: return imTrack
        case .subcutaneous:  return subQTrack
        case .oral, nil:     return []
        }
    }

    /// The site to OPEN ON: one step past the most recently logged site for this
    /// protocol, so consecutive injections never land in the same muscle. The web's
    /// `nextSiteIdx` (`DashboardContext.tsx`), same rule.
    ///
    /// `pins` may hold rows whose site is NULL (every iOS-written row before this) or a
    /// label that is not in this track (a protocol whose calculator type changed). Both
    /// are skipped rather than defaulted — an unrecognised label must not silently seed
    /// the rotation at index 0.
    ///
    /// With no usable history it falls back to `seed`, the protocol's position in the
    /// list, so two protocols logged on the same day do not both open on `L Glute`. The
    /// web offsets its seed by 3 (`(i + 3) % sites.length`); the offset is arbitrary
    /// there and reproducing it exactly is not possible anyway — iOS and the web do not
    /// order `saved_dosages` the same way — so this only reproduces the INTENT, which is
    /// that the seed differ per protocol.
    static func suggested(for dosage: SavedDosage, pins: [DoseLogPin], seed: Int = 0) -> String? {
        let sites = track(for: dosage)
        guard !sites.isEmpty else { return nil }

        let lastIndex = pins
            .filter { $0.protocolId == dosage.id }
            .compactMap { pin -> (String, Int)? in
                guard let site = pin.site, let idx = sites.firstIndex(of: site) else { return nil }
                return (pin.dosedOn, idx)
            }
            // `dosed_on` is a fixed "YYYY-MM-DD", so string order IS date order.
            .max { $0.0 < $1.0 }?.1

        if let lastIndex {
            return sites[(lastIndex + 1) % sites.count]
        }
        return sites[((seed % sites.count) + sites.count) % sites.count]
    }
}
