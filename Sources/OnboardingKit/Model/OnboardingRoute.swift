import Foundation

// ─── THE ROUTE ───────────────────────────────────────────────────────────────
//
// SPEC §3. The route is an ENUMERATED LIST PER BRANCH, not a filter over the
// full list.
//
// D7 — "enumerate exemptions, never predicate them; ask what could join the set
// tomorrow." A predicate like `steps.filter { !($0 == .benefit2 && exp == .adv) }`
// fits today's two routes exactly and is still the wrong shape: it silently
// decides for a fourth `OnboardingExperience` case that nobody has thought
// about. Written as two literal arrays behind an exhaustive switch, a new
// experience level cannot compile until someone says which screens it sees.

enum OnboardingRoute {

    /// SPEC §3 rows 1–9. The two end states are NOT on the route: they are
    /// reached from `paywall` by choosing a plan, and they are mutually
    /// exclusive.
    static let long: [OnboardingStep] = [
        .welcome,
        .pathway,
        .experience,
        .benefit1,
        .benefit2,
        .benefit3,
        .setup,
        .reminders,
        .inventory,
        .firstDose,
        .paywall,
    ]

    /// SPEC §3 rule 1: "`exp == .adv` → **one** benefit screen, then straight to
    /// `setup`." `benefit2` and `benefit3` are REMOVED, not hidden — they are
    /// not on this array at all, so nothing can navigate to them and `back()`
    /// cannot land on one.
    static let fastLane: [OnboardingStep] = [
        .welcome,
        .pathway,
        .experience,
        .benefit1,
        .setup,
        .reminders,
        .inventory,
        .firstDose,
        .paywall,
    ]

    /// The route for a given experience level.
    ///
    /// `exp` is `nil` until screen 3 commits it. Every step reachable while it
    /// is nil (`welcome`, `pathway`, `experience`) is a prefix shared by both
    /// routes, so `.none` returning `long` is correct rather than convenient —
    /// the arrays do not diverge until `benefit2`, which is past the point where
    /// `exp` is mandatory.
    ///
    /// Switched over `Optional<OnboardingExperience>` so all four inhabitants
    /// are written out. There is no `default`.
    static func steps(for exp: OnboardingExperience?) -> [OnboardingStep] {
        switch exp {
        case .none:        return long
        case .some(OnboardingExperience.first): return long
        case .some(OnboardingExperience.some):  return long
        case .some(OnboardingExperience.adv):   return fastLane
        }
    }
}

// ─── THE BRANCHES ────────────────────────────────────────────────────────────
//
// SPEC §3 lists SEVEN branch rules across three inputs. Every one of them is
// resolved here and nowhere else, so a screen never asks "what is `exp`?" — it
// asks this type for the thing it needs.
//
// The three inputs:
//   • `exp`      — rules 1, 2, 3, 4, 5.  Changes the route and four lines.
//   • `segment`  — the benefit copy and the paywall headline. Resolved inside
//                  OnboardingCopy (Benefits.all / Paywall.headline), because the
//                  effect is purely which words appear.
//   • `skipped`  — rules 6, 7.
//
// SPEC §2 says "`exp` changes the route and two individual lines". §3 then lists
// three exp-dependent lines (rules 3, 4, 5) plus the benefit CTA and the missing
// Skip from rule 1. §3 is the enumeration and is implemented; the "two" in §2 is
// a miscount and is recorded here rather than silently reconciled.

enum OnboardingBranch {

    /// Everything the `exp` dimension decides, resolved in one exhaustive
    /// switch per rule. Each function names its spec rule.
    struct ExperienceEffects: Equatable {
        /// SPEC §3 rule 1 / 2 — which benefit screens exist at all.
        let benefitSteps: [OnboardingStep]
        /// SPEC §3 rule 1 — "Set me up" on the fast lane, otherwise "Next".
        let benefitCTA: String
        /// SPEC §3 rule 1 — the fast lane shows NO Skip. Rule 2 — the others do.
        let benefitShowsSkip: Bool
        /// SPEC §3 rule 3 — the reassurance line, `.first` only.
        let setupExtraLine: String?
        /// SPEC §3 rule 4 — "＋ Add another compound" up front, `.adv` only.
        let setupShowsAddAnotherCompoundUpFront: Bool
        /// SPEC §3 rule 5 — the firstDose body.
        let firstDoseBody: String
    }

    static func effects(for exp: OnboardingExperience?) -> ExperienceEffects {
        switch exp {
        case .none:
            // Nothing on the pre-commit prefix reads any of these. The default
            // shape is the LONG route's, so a screen rendered before screen 3
            // commits cannot show the fast lane's CTA.
            return ExperienceEffects(
                benefitSteps: [.benefit1, .benefit2, .benefit3],
                benefitCTA: OnboardingCopy.Benefits.ctaNext,
                benefitShowsSkip: true,
                setupExtraLine: nil,
                setupShowsAddAnotherCompoundUpFront: false,
                firstDoseBody: OnboardingCopy.FirstDose.bodyDefault)

        case .some(OnboardingExperience.first):
            return ExperienceEffects(
                benefitSteps: [.benefit1, .benefit2, .benefit3],
                benefitCTA: OnboardingCopy.Benefits.ctaNext,
                benefitShowsSkip: true,
                setupExtraLine: OnboardingCopy.Setup.startWithWhatYouKnow,   // rule 3
                setupShowsAddAnotherCompoundUpFront: false,
                firstDoseBody: OnboardingCopy.FirstDose.bodyDefault)

        case .some(OnboardingExperience.some):
            return ExperienceEffects(
                benefitSteps: [.benefit1, .benefit2, .benefit3],
                benefitCTA: OnboardingCopy.Benefits.ctaNext,
                benefitShowsSkip: true,
                setupExtraLine: nil,
                setupShowsAddAnotherCompoundUpFront: false,
                firstDoseBody: OnboardingCopy.FirstDose.bodyDefault)

        case .some(OnboardingExperience.adv):
            return ExperienceEffects(
                benefitSteps: [.benefit1],                                    // rule 1
                benefitCTA: OnboardingCopy.Benefits.ctaSetMeUp,               // rule 1
                benefitShowsSkip: false,                                      // rule 1
                setupExtraLine: nil,
                setupShowsAddAnotherCompoundUpFront: true,                    // rule 4
                firstDoseBody: OnboardingCopy.FirstDose.bodyAdvanced)         // rule 5
        }
    }

    // MARK: - SPEC §3 rule 6 — the paywall opener

    /// "Paywall opener varies on how much was skipped: fewer than two skips →
    /// '— protocol set, reminders on'; otherwise '— your protocol, set up your
    /// way'."
    ///
    /// Written against the count of `OnboardingSkippableStep.allCases` rather
    /// than a literal 3, and with every reachable count listed rather than as
    /// `skipped.count < 2`.
    ///
    /// **This is the one branch in the flow that could not be made total.** The
    /// input is an `Int`, which has no exhaustive switch, so the `default` arm
    /// exists for counts that are unreachable while `OnboardingSkippableStep`
    /// has three cases. `skippableStepCountIsAsSpecced` below is the tripwire: a
    /// fourth skippable step makes it false, and the assertion fires in Debug
    /// pointing here.
    static func paywallOpener(skipped: Set<OnboardingSkippableStep>) -> String {
        assert(skippableStepCountIsAsSpecced,
               "OnboardingSkippableStep gained or lost a case. SPEC §3 rule 6 says "
               + "'fewer than two skips' against a three-member set — re-read the rule "
               + "and extend the enumeration below before shipping.")
        switch skipped.count {
        case 0, 1:
            return OnboardingCopy.Paywall.openerFewSkips
        case 2, 3:
            return OnboardingCopy.Paywall.openerManySkips
        default:
            // Unreachable while the set has three members; see the assert.
            return OnboardingCopy.Paywall.openerManySkips
        }
    }

    static let skippableStepCountIsAsSpecced = OnboardingSkippableStep.allCases.count == 3

    /// Convenience so the paywall screen never composes copy itself.
    static func paywallBody(skipped: Set<OnboardingSkippableStep>) -> String {
        OnboardingCopy.Paywall.body(opener: paywallOpener(skipped: skipped))
    }

    // MARK: - SPEC §3 rule 7 — the dashboard next-dose card

    /// "`dashboard` next-dose card reads 'reminder set ✓' or 'set a reminder?'
    /// depending on whether `reminders` was skipped."
    ///
    /// Switched over the `Bool`, which IS exhaustive — no `default`.
    static func dashboardNextDose(skipped: Set<OnboardingSkippableStep>) -> String {
        switch skipped.contains(.reminders) {
        case true:  return OnboardingCopy.Dashboard.nextDoseReminderPrompt
        case false: return OnboardingCopy.Dashboard.nextDoseReminderSet
        }
    }

    // MARK: - The dashboard's plan message

    /// SPEC §4 · 10a. `.declined` never reaches `dashboard` — it lands on
    /// `locked` — and `nil` cannot, because the plan is what routes here.
    static func dashboardMessage(plan: OnboardingPlan?) -> String? {
        switch plan {
        case .some(.trial):    return OnboardingCopy.Dashboard.trialMessage
        case .some(.paid):     return OnboardingCopy.Dashboard.paidMessage
        case .some(.declined): return nil
        case .none:            return nil
        }
    }
}
