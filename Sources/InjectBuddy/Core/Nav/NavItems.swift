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
    /// Mirrors the web exactly: of its 23 calculators, 19 save a protocol and 4
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

// MARK: - Listing

extension CalculatorSlug {
    /// Is this calculator offered on any surface a user can browse?
    ///
    /// H6, and the owner's words are the whole specification: *"leave them alone, and
    /// don't let the links to it go anywhere, we will work on later."* So the screen,
    /// the spec and the engine are untouched; what is withdrawn is every ROUTE IN.
    /// Re-enabling is deleting a case from this switch.
    ///
    /// REMOVED, NOT DISABLED, and that was decided rather than assumed. A row that
    /// renders and does nothing is the chevron defect already on the board — it
    /// promises navigation and delivers none.
    ///
    /// ENUMERATED, NOT PREDICATED (§5.32). The withdrawn set is two literal cases and
    /// cannot grow by accident: a calculator added tomorrow is listed unless somebody
    /// writes it in here. A predicate — `!canSaveProtocol`, say — would have swept in
    /// `cyclePlotter`, which is deliberately still reachable and is about to be built
    /// on.
    ///
    /// Separate from `canSaveProtocol` on purpose. That flag answers "can this finish
    /// the Add funnel"; this one answers "may a user get here at all". They overlap on
    /// two slugs today and that is a coincidence, not a relationship.
    ///
    /// **TWO DIFFERENT REASONS A CALCULATOR CAN BE ABSENT, AND THEY ARE NOT THE SAME
    /// STATE.** `isListed` is now the union of both, because every browse surface wants
    /// the same one question answered — "may a user get here" — but the two inputs are
    /// kept apart, because their invariants differ and a test pins each:
    ///
    ///   • `isWithdrawn` (H6) — the screen, spec, engine and category membership are
    ///     ALL intact and the owner intends to return to it. Re-enabling is deleting a
    ///     case. BMI and Free T Index.
    ///   • `isCollapsed` (T-12) — the calculator is GONE. No category, no route, and
    ///     nothing to restore. EOD.
    ///
    /// Collapsing through `isWithdrawn` would have been the easy edit and it would have
    /// broken three real invariants that `CalculatorLinkWithdrawalTests` asserts of a
    /// withdrawn slug: that it belongs to exactly one category, that it keeps a
    /// renderable spec, and that it cannot save. EOD satisfies none of those any more,
    /// and quietly relaxing the test to accommodate it would have cost the meaning of
    /// the withdrawal rather than the meaning of the collapse.
    ///
    /// STILL ENUMERATED, NOT PREDICATED (§5.32) — both inputs are literal switches, so
    /// the composition below cannot sweep anything in by accident.
    var isListed: Bool { !isWithdrawn && !isCollapsed }

    /// H6 — withdrawn from every route in; everything else about it is untouched.
    var isWithdrawn: Bool {
        switch self {
        case .bmi, .freeTestIndex: return true
        default: return false
        }
    }

    /// T-12 — collapsed into another calculator. The screen does not exist any more.
    ///
    /// The SLUG still does, and must: it decodes `saved_dosages.calculator_type`, and
    /// the web can still write this type. See `formSlug` for where it opens instead.
    var isCollapsed: Bool {
        switch self {
        case .eod: return true
        default: return false
        }
    }

    /// Every calculator a user is allowed to reach — the only list a browse surface may
    /// enumerate. `allCases` still contains the withdrawn and collapsed ones, because
    /// the screens, the specs and the saved-protocol decoding all still need them.
    static var listedCases: [CalculatorSlug] { allCases.filter(\.isListed) }

    /// The withdrawn set, named so a check can assert it is not empty. An exemption
    /// that exempts nothing is hiding that it exempts nothing (§5.32).
    static var withdrawnCases: [CalculatorSlug] { allCases.filter(\.isWithdrawn) }

    /// The collapsed set, named for the same reason.
    static var collapsedCases: [CalculatorSlug] { allCases.filter(\.isCollapsed) }

    /// Everything absent from browse, whatever the reason. This is what a "no route in"
    /// check should sweep; the two sets above are what an "and it still has/has not a
    /// screen" check should sweep.
    static var unlistedCases: [CalculatorSlug] { allCases.filter { !$0.isListed } }

    /// The calculator screen this slug OPENS. Identity for every slug but `.eod`.
    ///
    /// T-12 — EOD IS NO LONGER A CALCULATOR ON iOS. The owner's decision was to
    /// collapse it, *"that option is inside the TRT calc anyway"*, and the web agrees
    /// in its own nav: `nav-items.js:23` and `:59` both point `eod` at
    /// **`/trt-calculator/`**, the same URL as `trt`. So an EOD protocol opening the
    /// TRT calculator is what the web already does, not an iOS invention.
    ///
    /// THE SLUG ITSELF SURVIVES, AND THAT IS THE WHOLE POINT OF THIS PROPERTY.
    /// `CalculatorSlug.rawValue` is the decoder for `saved_dosages.calculator_type`,
    /// and the WEB CAN STILL WRITE `eod` — `app.js` keeps a live `EODPage` in `PAGES`
    /// (:9078) and `RAIL_PAGES` (:11316) whose save posts `calculator_type: 'eod'`
    /// (:6054). Delete the case and a web-created EOD protocol stops decoding here:
    /// no error, no empty state, it is simply absent. That is T-57's shape and
    /// T-81's — a live protocol missing from the screen the user checks.
    ///
    /// Redirecting at the SOURCE rather than at each push site, for the same reason
    /// `members` filters on `isListed` here rather than at every browse surface: a
    /// screen written next week inherits the collapse instead of having to remember it.
    var formSlug: CalculatorSlug { self == .eod ? .trt : self }
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

    /// Every calculator in this category a user may reach, savable or not.
    ///
    /// Filtered on `isListed` AT THE SOURCE (H6) rather than at each call site, so a
    /// browse surface written next week inherits the withdrawal instead of having to
    /// remember it. `allMembers` below is the unfiltered list, for code that needs to
    /// know which category a slug belongs to rather than to offer it to somebody.
    var members: [CalculatorSlug] { allMembers.filter(\.isListed) }

    /// Category membership, withdrawn calculators included. Not a browse surface.
    var allMembers: [CalculatorSlug] {
        switch self {
        case .glp1:    return [.semaglutide, .tirzepatide, .retatrutide, .bmi]
        // T-12 — `.eod` is REMOVED from category membership, not merely unlisted.
        // `isListed` withdraws a screen that still exists (BMI, Free T Index); this is
        // a collapse, so EOD leaves the taxonomy entirely and no browse surface,
        // Add-funnel step or drawer can enumerate it. `CalculatorSlug.eod` still
        // exists to DECODE a web-written protocol — see `formSlug`.
        case .hormone: return [.trt, .microdose, .hcg, .freeTestIndex]
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
    /// The cycle plotter, OPENED ON SOMETHING — T-17.
    ///
    /// A SECOND ROUTE TO THE SAME SCREEN, and enumerated rather than folded into
    /// `.calculator(.cyclePlotter)`, because the two are different destinations even
    /// though they draw the same view. `.calculator(.cyclePlotter)` is the drawer's
    /// and the Tools hub's route: nothing has been calculated, so there is nothing to
    /// open on and an empty plotter is the correct arrival. This one is the route out
    /// of a calculator's "See your levels over time", where the user has just typed a
    /// compound, a dose and an interval — and T-17 is that they were made to type
    /// them again.
    ///
    /// Adding the payload to `.calculator` instead was the other option and it is
    /// worse: every construction of `.calculator(slug)` in the app would have to say
    /// what it is not carrying, and `NavItems.calculators` would grow a `nil` on all
    /// fifteen entries to serve one of them.
    ///
    /// STILL `Hashable`, which is not free — `AppRoute` is a `navigationDestination`
    /// value and the drawer's selection. `PlotterSeed` is a struct of a `String`, two
    /// `Double`s and a `CalculatorSlug`, all `Hashable`, so the synthesised conformance
    /// carries through.
    case plotter(seed: PlotterSeed)
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
        // The same title as the unseeded route. It is the same screen, and the back
        // control of anything pushed from it should read the same either way.
        case .plotter: return CalculatorSlug.cyclePlotter.title
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
        case .plotter: return CalculatorSlug.cyclePlotter.icon
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

    /// Every calculator the drawer may route to, in canonical order.
    ///
    /// `listedCases`, not `allCases` — the drawer is a link surface like any other, and
    /// H6 withdraws BMI and Free T Index from all of them. It was the third one, and it
    /// was not in the spec: the drawer is live on iPhone and listed all fifteen.
    /// The count is deliberately not written in this comment; it was "All 14" while the
    /// expression returned fifteen, which is §5.31 on a one-line doc string.
    static let calculators: [AppRoute] = CalculatorSlug.listedCases.map { .calculator($0) }

    /// Sections rendered, in order, by the drawer + iPad sidebar.
    static let sections: [NavSection] = [
        NavSection(eyebrow: nil, routes: primary),
        NavSection(eyebrow: "Calculators", routes: calculators),
        NavSection(eyebrow: nil, routes: [.settings]),
    ]
}
