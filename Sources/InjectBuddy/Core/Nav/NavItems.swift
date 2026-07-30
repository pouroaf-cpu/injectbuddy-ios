import SwiftUI

// ─── NavItems ────────────────────────────────────────────────────────────────
// THE SINGLE SOURCE for everything the drawer lists and the app routes to. Never
// duplicate the calculator list anywhere else (WIREFRAME-PLAN §5). The drawer, the
// iPad sidebar, and the dashboard "open calculator" picker all read from here.
//
// CalculatorSlug.rawValue == the Supabase `saved_dosages.calculator_type` string the
// web app writes (the short internal slugs: trt, eod, bpc157, …), so a protocol saved
// on the web shows on iOS and vice-versa. (Verify against public/app.js if a calc's
// saved type is ever in doubt — these mirror nav.js FAV_MAP + the calculator pages.)

enum CalculatorSlug: String, CaseIterable, Identifiable, Hashable {
    case trt            = "trt"
    case eod            = "eod"
    case hcg            = "hcg"
    case peptide        = "peptide"
    case reconstitution = "reconstitution"
    case semaglutide    = "semaglutide"
    case tirzepatide    = "tirzepatide"
    case retatrutide    = "retatrutide"
    case bpc157         = "bpc157"
    case bpc157blend    = "bpc157blend"
    case bmi            = "bmi"
    case freeTestIndex  = "freetest"
    case microdose      = "microdose"
    case cyclePlotter   = "plotter"
    /// The web's /steroid-dosage-calculator/ hub. One screen, 12 compounds behind a
    /// picker (SteroidCatalog) — matching the web, which is likewise one data-driven
    /// page rather than a calculator per compound.
    case steroid        = "steroid"

    var id: String { rawValue }

    /// Display label — matches the web CALC_ITEMS labels (SharedNav.tsx).
    var title: String {
        switch self {
        case .trt: return "TRT Dose"
        case .eod: return "TRT & EOD"
        case .hcg: return "HCG"
        case .peptide: return "Peptide"
        case .reconstitution: return "Reconstitution"
        case .semaglutide: return "Semaglutide"
        case .tirzepatide: return "Tirzepatide"
        case .retatrutide: return "Retatrutide"
        case .bpc157: return "BPC-157"
        case .bpc157blend: return "BPC+TB500"
        case .bmi: return "BMI"
        case .freeTestIndex: return "Free T Index"
        case .microdose: return "TRT Microdose"
        case .cyclePlotter: return "Cycle Plotter"
        case .steroid: return "Steroid Dosage"
        }
    }

    /// A short abbreviation for compact contexts (protocol cards, favourites).
    var shortTitle: String {
        switch self {
        case .trt: return "TRT"
        case .eod: return "EOD"
        case .freeTestIndex: return "FTI"
        case .bpc157blend: return "Blend"
        case .semaglutide: return "Sema"
        case .tirzepatide: return "Tirz"
        case .retatrutide: return "Reta"
        case .reconstitution: return "Recon"
        case .microdose: return "Micro"
        case .cyclePlotter: return "Plotter"
        case .steroid: return "Steroid"
        default: return title
        }
    }

    var icon: String {
        switch self {
        case .trt, .eod, .microdose: return "syringe"
        case .hcg: return "drop"
        case .peptide, .reconstitution: return "testtube.2"
        case .semaglutide, .tirzepatide, .retatrutide: return "pills"
        case .bpc157, .bpc157blend: return "bandage"
        case .bmi: return "figure.stand"
        case .freeTestIndex: return "waveform.path.ecg"
        case .cyclePlotter: return "chart.xyaxis.line"
        case .steroid: return "pills.circle"
        }
    }
}

// MARK: - Saving

extension CalculatorSlug {
    /// Can this calculator produce a protocol the app can store?
    ///
    /// Mirrors the web exactly: of its 23 calculators, 19 POST to /api/dosages and 4
    /// never do — bmi, plotter, freetest and ftv compute and display only. Of the 15
    /// slugs this app has, three of those four are present, so 12 can save.
    ///
    /// This is what keeps dead ends out of the Add funnel: a picker that offers a
    /// calculator with no save path walks the user into a wall at the last step.
    var canSaveProtocol: Bool {
        switch self {
        case .bmi, .freeTestIndex, .cyclePlotter: return false
        default: return true
        }
    }
}

// MARK: - Categories

/// The Add funnel's first question, "what are you adding?".
///
/// Mirrors the web's IB_NAV.groups (public/nav-items.js) — same four buckets, same
/// keys — so the two products sort calculators the same way. Order matches the web
/// Add page rather than the nav dropdowns.
///
/// NOTE: `steroid` carries the Steroid Dosage hub (12 compounds) but NOT the web's
/// other two steroid tools — Blend (oilblend) and Bioavailability. Their maths is not
/// ported, and a calculator that shows a confidently wrong number in this niche is
/// worse than one that is absent, so they stay out until the formulas are carried
/// across (TASK 18). `visibleCases` still guards against a category emptying out.
enum CalculatorCategory: String, CaseIterable, Identifiable, Hashable {
    case glp1
    case hormone
    case peptide
    case steroid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glp1: return "GLP-1"
        case .hormone: return "Testosterone & hormones"
        case .peptide: return "Peptides"
        case .steroid: return "Steroids"
        }
    }

    var subtitle: String {
        switch self {
        case .glp1: return "Semaglutide, tirzepatide, retatrutide"
        case .hormone: return "TRT, microdosing, HCG"
        case .peptide: return "BPC-157, blends, reconstitution"
        case .steroid: return "Steroid dosing and oil blends"
        }
    }

    var icon: String {
        switch self {
        case .glp1: return "pills"
        case .hormone: return "syringe"
        case .peptide: return "testtube.2"
        case .steroid: return "flask"
        }
    }

    /// Every calculator in this category, savable or not.
    var members: [CalculatorSlug] {
        switch self {
        case .glp1:    return [.semaglutide, .tirzepatide, .retatrutide, .bmi]
        case .hormone: return [.trt, .eod, .microdose, .hcg, .freeTestIndex]
        case .peptide: return [.peptide, .reconstitution, .bpc157, .bpc157blend]
        case .steroid: return [.steroid]
        }
    }

    /// What the Add funnel offers — members that can actually finish the flow.
    var savableMembers: [CalculatorSlug] { members.filter(\.canSaveProtocol) }

    /// Categories worth showing in the funnel. Hides any that would open on nothing.
    static var visibleCases: [CalculatorCategory] {
        allCases.filter { !$0.savableMembers.isEmpty }
    }
}

// MARK: - App routes

/// Everything the content NavigationStack can show. Hashable so it works as a
/// navigationDestination value and as the drawer selection.
enum AppRoute: Hashable {
    case dashboard
    case calendar
    case tools
    case add
    /// Category chosen; pick the calculator. Second step of the Add funnel.
    case addCategory(CalculatorCategory)
    /// Last step: a protocol exists, confirm the day it starts.
    case addConfirm(dosageId: String)
    case calculator(CalculatorSlug)
    case settings

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .calendar: return "Calendar"
        case .tools: return "Tools"
        case .add: return "Add"
        case .addCategory(let c): return c.title
        case .addConfirm: return "Start day"
        case .settings: return "Settings"
        case .calculator(let slug): return slug.title
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .calendar: return "calendar"
        case .tools: return "flask"
        case .add: return "plus"
        case .addCategory(let c): return c.icon
        case .addConfirm: return "calendar.badge.clock"
        case .settings: return "gearshape"
        case .calculator(let slug): return slug.icon
        }
    }
}

// MARK: - Bottom tabs

/// The five slots of the bottom bar, mirroring the web's ib-bottomnav.js:
/// Dashboard · Calendar · Log dose (raised hero) · Tools · Add.
///
/// `log` is a slot, not a destination — selecting it opens the log sheet and the
/// current tab stays put. MainShell intercepts it; see the binding there.
enum MainTab: Hashable, CaseIterable {
    case dashboard, calendar, log, tools, add

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .calendar: return "Calendar"
        case .log: return "Log dose"
        case .tools: return "Tools"
        case .add: return "Add"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house"
        case .calendar: return "calendar"
        case .log: return "syringe"
        case .tools: return "flask"
        case .add: return "plus"
        }
    }

    /// The root route this tab shows. nil for `log`, which has no screen of its own.
    var route: AppRoute? {
        switch self {
        case .dashboard: return .dashboard
        case .calendar: return .calendar
        case .tools: return .tools
        case .add: return .add
        case .log: return nil
        }
    }
}

// MARK: - Drawer model

struct NavSection: Identifiable {
    let id = UUID()
    var eyebrow: String?
    var routes: [AppRoute]
}

enum NavItems {
    /// Primary destinations shown above the calculators.
    static let primary: [AppRoute] = [.dashboard, .calendar]

    /// All 14 calculators, in canonical order.
    static let calculators: [AppRoute] = CalculatorSlug.allCases.map { .calculator($0) }

    /// Sections rendered, in order, by the drawer + iPad sidebar.
    static let sections: [NavSection] = [
        NavSection(eyebrow: nil, routes: primary),
        NavSection(eyebrow: "Calculators", routes: calculators),
        NavSection(eyebrow: nil, routes: [.settings]),
    ]
}
