import SwiftUI

// ─── SCREENS 10a / 10b · the two end states ──────────────────────────────────
//
// Neither carries a progress bar — SPEC §3 tabulates no percentage for them, and
// `barPercent` is `nil` there, so the scaffold draws none.
//
// **THE LOOP IS THE END STATE.** SPEC §1: "Do not add a 'you have finished'
// interstitial." Both terminals return to `welcome` with `segment`, `exp`,
// `skipped`, `plan` and every collected field cleared — that is what makes this
// a testing surface rather than a demo. `flow.finish()` does it, and it is the
// only thing on either screen that is a DEBUG affordance rather than design.

// MARK: - 10a · dashboard (accepted)

/// SPEC §4: "Shows: active levels chart (alive with their first dose) · next
/// dose card · cycle plotter pre-loaded."
///
/// ***THOSE THREE ARE MOCKS OF REAL UI, NOT ILLUSTRATIONS.*** SPEC §5 is
/// explicit that they "are NOT part of the fifteen and must never reach the art
/// list", so they are drawn with `OnboardingUIMock` — neutral, dashed, labelled
/// MOCK — and never with the warning-coloured `OnboardingIllustrationPlaceholder`
/// that marks missing art. A screenshot of this screen must not read as three
/// more assets to commission.
struct OnboardingDashboardScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            OnboardingTitle(text: OnboardingCopy.Dashboard.title)

            // `.trial` and `.paid` each have their own line; `.declined` never
            // lands here, it lands on `locked`.
            if let message = OnboardingBranch.dashboardMessage(plan: flow.state.plan) {
                OnboardingBody(text: message)
            }

            OnboardingUIMock(label: OnboardingCopy.Dashboard.mockActiveLevelsChart) {
                Text(OnboardingCopy.Dashboard.mockActiveLevelsDetail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }

            OnboardingUIMock(label: OnboardingCopy.Dashboard.mockNextDoseCard) {
                // SPEC §3 rule 7 — "reminder set ✓" or "set a reminder?",
                // depending on whether `reminders` was skipped. This is the line
                // the sixth verification path exists to see.
                OnboardingSupportingLine(
                    text: OnboardingBranch.dashboardNextDose(skipped: flow.state.skipped),
                    identifier: "onboarding.dashboard.nextDose")
            }

            OnboardingUIMock(label: OnboardingCopy.Dashboard.mockCyclePlotter) {
                Text(OnboardingCopy.Dashboard.mockCyclePlotterDetail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            OnboardingSecondaryButton(
                title: OnboardingCopy.Debug.finishAndLoop,
                identifier: "onboarding.finish"
            ) {
                flow.finish()
            }
        }
    }
}

// MARK: - 10b · locked (declined)

/// "See plans again" goes BACK to the paywall and clears `plan`, so a second
/// decision is a decision rather than an amendment to a recorded one. It does
/// not loop — looping is `finish()`, and it is a separate control.
struct OnboardingLockedScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            OnboardingTitle(text: OnboardingCopy.Locked.title)
            OnboardingBody(text: OnboardingCopy.Locked.body)
        } actions: {
            OnboardingPrimaryButton(
                title: OnboardingCopy.Locked.cta,
                identifier: "onboarding.locked.seePlans"
            ) {
                flow.seePlansAgain()
            }
            OnboardingSecondaryButton(
                title: OnboardingCopy.Debug.finishAndLoop,
                identifier: "onboarding.finish"
            ) {
                flow.finish()
            }
        }
    }
}
