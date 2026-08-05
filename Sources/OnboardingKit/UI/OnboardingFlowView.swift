import SwiftUI

// ─── THE ROOT VIEW ───────────────────────────────────────────────────────────
//
// `OnboardingPreview`'s root view IS this. SPEC §1: "Launch it in the simulator
// and you are on screen 1."
//
// **THE SWITCH BELOW IS THE CHECKLIST.** It is exhaustive with no `default`, so
// every one of the thirteen screens has a line here that has to be visited — and
// a fourteenth screen cannot be added without this file saying what it draws.
// The foundation pass (a15c62f) rendered a labelled scaffold from every arm; the
// screens pass replaced them, one arm at a time, with the views in `UI/Screens/`.
//
// Two things nothing downstream may undo:
//   • **No string literals in views.** Every word on screen comes from
//     `OnboardingCopy`, including the accessibility labels. If a word is
//     missing, it gets added THERE.
//   • **D5** — the primary action must be reachable without scrolling at every
//     text size, and so must the input it commits. The mechanism is
//     `OnboardingScreenScaffold`'s PINNED FOOTER: actions live outside the
//     scroll view, so body copy cannot push a CTA off the screen however far it
//     grows. `setup` is the screen where the second half of that rule is a
//     measurement rather than a structure, and it is called out there.
//
// The chrome — back, the debug restart and the exact progress bar — belongs to
// the scaffold, so it is identical on every screen by construction rather than
// by thirteen screens agreeing.

struct OnboardingFlowView: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        stepContent
            // The step is the view's identity. Without this, SwiftUI reuses one
            // screen's `@State` for the next — which is how a reminder time
            // typed on screen 6 would turn up prefilled after a loop.
            .id(flow.step)
    }

    // MARK: - The thirteen screens

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {

        case .welcome:
            OnboardingWelcomeScreen(flow: flow)

        case .pathway:
            OnboardingPathwayScreen(flow: flow)

        case .experience:
            OnboardingExperienceScreen(flow: flow)

        // One view, three steps: which benefit is on show is the ROUTE's
        // business, and `.adv` only ever reaches the first of them.
        case .benefit1, .benefit2, .benefit3:
            OnboardingBenefitScreen(flow: flow)

        case .setup:
            OnboardingSetupScreen(flow: flow)

        case .reminders:
            OnboardingRemindersScreen(flow: flow)

        case .inventory:
            OnboardingInventoryScreen(flow: flow)

        case .firstDose:
            OnboardingFirstDoseScreen(flow: flow)

        case .paywall:
            OnboardingPaywallScreen(flow: flow)

        case .dashboard:
            OnboardingDashboardScreen(flow: flow)

        case .locked:
            OnboardingLockedScreen(flow: flow)
        }
    }
}
