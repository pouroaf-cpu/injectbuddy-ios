import SwiftUI

// ─── SCREENS 4a / 4b / 4c · benefits ─────────────────────────────────────────
//
// Bars 55% / 62% / 69%. One view for all three: which benefit is on show is the
// route's business, and the copy comes from `segment`.
//
// BOTH BRANCH DIMENSIONS MEET HERE, and this screen resolves neither of them
// itself:
//   • `segment` picks the words — `flow.currentBenefit`.
//   • `exp` picks the CTA and whether there is a Skip at all — `flow.branch`.
//     SPEC §3 rule 1: `.adv` sees ONE benefit screen, its CTA reads "Set me up",
//     and it shows NO Skip. Rule 2: everyone else sees three, each with a ghost
//     Skip that jumps to `setup`.
//
// The illustration is the one thing this screen looks up by hand, because the
// asset depends on the segment AND the index and `forStep` has neither.

struct OnboardingBenefitScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            if let art = illustration {
                OnboardingIllustrationPlaceholder(illustration: art)
            }
            if let benefit = flow.currentBenefit {
                OnboardingTitle(text: benefit.title)
                OnboardingBody(text: benefit.body)
            }
        } actions: {
            // SPEC §3 rule 1 — "Set me up" on the fast lane, "Next" otherwise.
            OnboardingPrimaryButton(title: flow.branch.benefitCTA) {
                flow.advance()
            }
            // SPEC §3 rule 1 — the fast lane shows NO Skip. Rule 2 — the others
            // do, and it jumps to `setup` without counting as a skipped step.
            if flow.branch.benefitShowsSkip {
                OnboardingGhostButton(title: OnboardingCopy.Benefits.ctaSkip) {
                    flow.skipBenefits()
                }
            }
        }
    }

    /// `nil` before `segment` is committed, which cannot happen — screen 2 is
    /// mandatory and precedes every benefit screen.
    private var illustration: OnboardingIllustration? {
        guard let segment = flow.state.segment,
              let index = flow.benefitIndex(of: flow.step)
        else { return nil }
        return OnboardingIllustration.forBenefit(segment: segment, index: index - 1)
    }
}
