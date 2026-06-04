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
        }
    }
}

// MARK: - App routes

/// Everything the content NavigationStack can show. Hashable so it works as a
/// navigationDestination value and as the drawer selection.
enum AppRoute: Hashable {
    case dashboard
    case calendar
    case calculator(CalculatorSlug)
    case settings

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .calendar: return "Calendar"
        case .settings: return "Settings"
        case .calculator(let slug): return slug.title
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .calendar: return "calendar"
        case .settings: return "gearshape"
        case .calculator(let slug): return slug.icon
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
