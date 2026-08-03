import Foundation

// ─── OnboardingKit — the boundary ────────────────────────────────────────────
//
// SPEC: docs/SPEC-ONBOARDING.md. This folder is compiled into BOTH the
// `InjectBuddy` app target and the `OnboardingPreview` app target (see
// project.yml). It is source-included in each, not a framework, so everything
// here is same-module in both.
//
// THE BOUNDARY, per SPEC §1: OnboardingKit depends on nothing in
// `Core/Backend`, nothing in `Core/Auth`, and nothing in `Features/`. It may
// depend on `Core/Theme` (which is added to the preview target's source paths
// for exactly this reason) and on plain models it defines itself.
//
// If you find yourself reaching for one of the forbidden imports: STOP. That is
// a finding about the seam, and it goes in a report — it is not a reason to
// import. SPEC §1: "If OnboardingKit needs anything from the app that would
// drag Core/Backend in with it, that is a finding about the boundary."

// MARK: - Branch dimension 1 — segment (SPEC §2, set on screen 2, mandatory)

/// Selects the benefit copy and the paywall headline. Nothing else.
///
/// `allCases` order IS the on-screen option order for `pathway` — the screens
/// pass renders the options by iterating this, so the order lives here and not
/// in a view.
enum OnboardingSegment: String, CaseIterable, Hashable {
    case trt
    case glp
    case aas
    case other
}

// MARK: - Branch dimension 2 — experience (SPEC §2, set on screen 3, mandatory)

/// Changes the ROUTE (`.adv` removes two screens) and a small number of
/// individual lines. See `OnboardingBranch` — every effect is enumerated there,
/// never predicated (D7).
///
/// `allCases` order IS the on-screen option order for `experience`.
enum OnboardingExperience: String, CaseIterable, Hashable {
    case first
    case some
    case adv
}

// MARK: - Skippable steps (SPEC §2: `skipped: Set<Step>`)

/// The complete set of steps a user may skip. SPEC §2 names exactly three.
///
/// This enum is the authority for "how many skips are possible" — the paywall
/// opener variant (SPEC §3 rule 6) is written against it rather than against a
/// hard-coded 3.
///
/// NOTE: the benefit screens' ghost "Skip" (SPEC §3 rule 2) jumps to `setup`
/// but is NOT a member of this set — it does not count toward the paywall
/// opener variant, because SPEC §2 lists only these three.
enum OnboardingSkippableStep: String, CaseIterable, Hashable {
    case reminders
    case inventory
    case firstDose
}

// MARK: - Plan (SPEC §2)

enum OnboardingPlan: String, CaseIterable, Hashable {
    /// `Start my 7-day free trial · $X/mo`
    case trial
    /// `Skip the trial — 10% off first 3 months`
    case paid
    /// ghost `Not now`
    case declined
}

// MARK: - Unit preference (SPEC §4, screen 5: "mg · mL · IU · units")

/// `allCases` order IS the on-screen option order.
enum OnboardingUnitPreference: String, CaseIterable, Hashable {
    case mg
    case mL
    case iu
    case units
}

// MARK: - The state

/// Everything the flow collects. In memory only.
///
/// **This type is never written anywhere in this pass.** It is handed to an
/// `OnboardingSink` at the end; the preview target's sink is a no-op. Before
/// building a real sink read `docs/WELCOME-AND-ONBOARDING.md` §3 and
/// `docs/DATA-CONTRACT.md` — see the warning on `OnboardingSink`.
///
/// **The free-text numeric fields are `String`, deliberately.** SPEC §1: "No
/// rounding on the way in. A user entering 180 lb must get 180 lb back."
/// Keeping the raw entry means no coercion happens between the keyboard and the
/// sink, and the sink — which is the thing that knows the contract — does the
/// parsing.
struct OnboardingState: Equatable {

    /// Screen 1's name. SPEC §3.1.
    ///
    /// **The personalisation key for everything after it**, and it is **optional** — the
    /// screen has a Skip and this may legitimately be empty. `OnboardingCopy.personalised`
    /// is the only thing that reads it, and it treats trimmed-empty as *absent*.
    ///
    /// **Destined for `profiles.nickname` — the SAME column `WELCOME-AND-ONBOARDING.md`
    /// §3 step 1 owns, not a new one.** That is what dissolves the two-flows-both-asking
    /// collision rather than managing it. Still a no-op sink in this pass.
    ///
    /// **In the `OnboardingPreview` target there is no session**, so the `display_name`
    /// rung of §3.1's three (`nickname` → `display_name` → nameless copy) is unavailable
    /// and an empty name always falls to the nameless copy. **That is correct behaviour,
    /// not a bug** — it is written here because it will look like one.
    var name: String = ""

    // Branch dimensions
    var segment: OnboardingSegment? = nil
    var exp: OnboardingExperience? = nil
    var skipped: Set<OnboardingSkippableStep> = []
    var plan: OnboardingPlan? = nil

    // Collected — setup (screen 5)
    var units: OnboardingUnitPreference? = nil
    var compound: String = ""
    var dose: String = ""
    var frequency: String = ""
    var extraCompounds: [String] = []

    // Collected — reminders (screen 6). Time of day only; the date part is
    // meaningless and must not reach a sink.
    var reminderTime: Date? = nil

    // Collected — inventory (screen 7)
    var vialCount: String = ""
    var vialSize: String = ""

    init() {}

    /// SPEC §1: "Reset every field, not just the route. A stale `segment`
    /// leaking across a loop shows the wrong benefit copy on the next pass and
    /// reads as a copy bug — a defect in the thing being tested, blamed on the
    /// thing that is correct."
    ///
    /// **Written as whole-value replacement on purpose.** A field-by-field reset
    /// is a list that someone has to remember to extend; `self = OnboardingState()`
    /// cannot be out of date, because a new stored property with a default is
    /// cleared the moment it is declared and a new property WITHOUT a default
    /// fails to compile here. Do not "optimise" this into individual assignments.
    mutating func reset() {
        self = OnboardingState()
    }
}
