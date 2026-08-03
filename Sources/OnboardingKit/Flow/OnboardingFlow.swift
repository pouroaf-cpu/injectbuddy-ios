import Foundation
import Combine

// ─── THE STATE MACHINE ───────────────────────────────────────────────────────
//
// The single object the screens talk to. It owns the current step, the
// collected state, and the history stack that makes `back()` work from every
// screen (SPEC §3).
//
// It knows nothing about SwiftUI layout, nothing about the network, and nothing
// about copy beyond handing branch-resolved lines through from
// `OnboardingBranch`. A screen should never need to read `state.exp` to decide
// what to draw — ask this object.

@MainActor
final class OnboardingFlow: ObservableObject {

    /// The screen currently on show.
    @Published private(set) var step: OnboardingStep = .welcome

    /// Everything collected so far. In memory. Never written by this type.
    @Published var state = OnboardingState()

    /// Where `back()` goes, innermost last. Not derived from the route, because
    /// the route can CHANGE underneath the user (going back to `experience` and
    /// picking `.adv` shortens it) and a derived index would then point at a
    /// screen that no longer exists.
    private var history: [OnboardingStep] = []

    private let sink: OnboardingSink

    init(sink: OnboardingSink) {
        self.sink = sink
    }

    // MARK: - Derived, for the screens

    /// The route the user is currently on. Changes the moment `exp` is set.
    var route: [OnboardingStep] { OnboardingRoute.steps(for: state.exp) }

    /// Every `exp`-dependent effect, resolved. SPEC §3 rules 1–5.
    var branch: OnboardingBranch.ExperienceEffects { OnboardingBranch.effects(for: state.exp) }

    /// SPEC §3 — exact, and worth asserting rather than eyeballing.
    var barPercent: Int? { step.barPercent }
    var barFraction: Double? { step.barFraction }

    /// SPEC §3: "Back must work from every screen." False only on `welcome`,
    /// where there is nothing behind.
    var canGoBack: Bool { !history.isEmpty }

    /// Which of the three benefit screens this is (1-based), for the copy
    /// lookup. `nil` on any non-benefit step.
    func benefitIndex(of step: OnboardingStep) -> Int? {
        branch.benefitSteps.firstIndex(of: step).map { $0 + 1 }
    }

    /// The benefit copy for the current benefit screen. `nil` off a benefit
    /// screen, or before `segment` is committed (which cannot happen — screen 2
    /// is mandatory and precedes every benefit screen).
    var currentBenefit: OnboardingCopy.Benefit? {
        guard let segment = state.segment,
              let index = branch.benefitSteps.firstIndex(of: step)
        else { return nil }
        let all = OnboardingCopy.Benefits.all(for: segment)
        guard all.indices.contains(index) else { return nil }
        return all[index]
    }

    // MARK: - Forward

    /// Advance one step along the CURRENT route.
    ///
    /// No-op on the two end states — leaving those is `finish()` (loop) or, from
    /// `locked`, `seePlansAgain()`.
    func advance() {
        let route = self.route
        guard let index = route.firstIndex(of: step), index + 1 < route.count else { return }
        go(to: route[index + 1])
    }

    /// SPEC §3 rule 2 — the benefit screens' ghost "Skip" jumps to `setup`.
    ///
    /// Deliberately NOT recorded in `state.skipped`: SPEC §2 lists exactly three
    /// skippable steps and the benefit screens are not among them, so this must
    /// not move the paywall opener variant (rule 6).
    func skipBenefits() {
        go(to: .setup)
    }

    /// Skip an optional step. Records it (rules 6 and 7 read this) and advances.
    func skip(_ skippable: OnboardingSkippableStep) {
        state.skipped.insert(skippable)
        advance()
    }

    /// Skip whatever the current screen is, if it is skippable. No-op otherwise.
    func skipCurrent() {
        guard let skippable = step.skippable else { return }
        skip(skippable)
    }

    // MARK: - Choices

    /// Screen 2, mandatory. Sets branch dimension 1 and advances.
    func choose(segment: OnboardingSegment) {
        state.segment = segment
        advance()
    }

    /// Screen 3, mandatory. Sets branch dimension 2 — which may SHORTEN the
    /// route — and advances onto the newly-selected route.
    func choose(exp: OnboardingExperience) {
        state.exp = exp
        advance()
    }

    /// Screen 9. Routes to one of the two end states.
    ///
    /// Enumerated over all three plans; there is no `default`, so a fourth plan
    /// must state which terminal it lands on.
    func choose(plan: OnboardingPlan) {
        state.plan = plan
        switch plan {
        case .trial:    go(to: .dashboard)
        case .paid:     go(to: .dashboard)
        case .declined: go(to: .locked)
        }
    }

    // MARK: - Back

    /// SPEC §3: "Back must work from every screen."
    func back() {
        guard let previous = history.popLast() else { return }
        step = previous
    }

    /// SPEC §4 · 10b — `See plans again`. Returns to the paywall. It is a normal
    /// backward move, not a loop, and the plan is cleared so a second decision
    /// is a decision and not an amendment to a recorded one.
    func seePlansAgain() {
        state.plan = nil
        back()
    }

    // MARK: - The loop

    /// **THE END STATE IS THE LOOP.** SPEC §1: both terminals return to
    /// `welcome`, and SPEC §1 again: "Do not add a 'you have finished'
    /// interstitial."
    ///
    /// Hands the collected state to the sink FIRST — the preview's sink is a
    /// no-op — then clears everything: `segment`, `exp`, `skipped`, `plan` and
    /// every collected field, plus the history stack and the step.
    ///
    /// The reset is `OnboardingState.reset()`, which is whole-value replacement,
    /// so it cannot go stale as fields are added. A leaked `segment` would show
    /// the wrong benefit copy on the next pass and read as a copy bug — a defect
    /// in the thing being tested, blamed on the thing that is correct.
    ///
    /// No-op off an end state: enumerated over every step so a new terminal has
    /// to say so here.
    func finish() {
        let endState: OnboardingEndState
        switch step {
        case .dashboard:
            endState = .dashboard
        case .locked:
            endState = .locked
        case .welcome, .pathway, .experience, .benefit1, .benefit2, .benefit3,
             .setup, .reminders, .inventory, .firstDose, .paywall:
            return
        }
        sink.onboardingDidFinish(state, at: endState)
        resetToStart()
    }

    /// Debug affordance only — SPEC §3: "The wireframe also has a restart; the
    /// preview target should keep one, as a debug affordance only."
    ///
    /// Unlike `finish()` this does NOT call the sink. Abandoning a walk-through
    /// is not completing one.
    func restart() {
        resetToStart()
    }

    // MARK: - Internals

    private func go(to next: OnboardingStep) {
        history.append(step)
        step = next
    }

    private func resetToStart() {
        state.reset()
        history.removeAll()
        step = .welcome
    }
}
