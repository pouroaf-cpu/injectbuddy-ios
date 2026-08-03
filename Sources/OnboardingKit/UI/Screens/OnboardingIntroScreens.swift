import SwiftUI

// ─── SCREENS 1–3 ─────────────────────────────────────────────────────────────
//
// `welcome`, then the two mandatory branch screens.
//
// Not one string below is a literal: every word comes from `OnboardingCopy`
// (SPEC §4). The option lists are driven off `allCases` of the branch enums, so
// there is no parallel array of labels that can fall out of step with the type.

// MARK: - 1 · welcome (bar 25%)

/// SPEC §1: "Screen 1 assumes the user has already signed up." There is no auth
/// here because the flow begins immediately after account creation, not because
/// it happens before sign-up.
struct OnboardingWelcomeScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            if let art = OnboardingIllustration.forStep(.welcome) {
                OnboardingIllustrationPlaceholder(illustration: art)
            }
            OnboardingTitle(text: OnboardingCopy.Welcome.title)
            OnboardingBody(text: OnboardingCopy.Welcome.body)
        } actions: {
            OnboardingPrimaryButton(title: OnboardingCopy.Welcome.cta) {
                flow.advance()
            }
        }
    }
}

// MARK: - 2 · pathway (bar 35%) — branch dimension 1, mandatory

/// Sets `segment`, which selects the benefit copy and the paywall headline.
///
/// **No footer.** The four options ARE the primary action on this screen, so
/// putting an empty action bar under them would only steal the height they need
/// to stay reachable (D5).
struct OnboardingPathwayScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow, showsFooter: false) {
            OnboardingTitle(text: OnboardingCopy.Pathway.title)
            OnboardingBody(text: OnboardingCopy.Pathway.body)
            VStack(spacing: Theme.Spacing.sm) {
                // Order comes from `OnboardingSegment.allCases`, which is where
                // the model says it lives — not from a list retyped in a view.
                ForEach(OnboardingSegment.allCases, id: \.self) { segment in
                    OnboardingChoiceRow(
                        title: OnboardingCopy.Pathway.option(segment),
                        identifier: "onboarding.pathway.\(segment.rawValue)"
                    ) {
                        flow.choose(segment: segment)
                    }
                }
            }
        } actions: {
            EmptyView()
        }
    }
}

// MARK: - 3 · experience (bar 45%) — branch dimension 2, mandatory

/// Sets `exp`, which changes the ROUTE (`.adv` removes two benefit screens) and
/// three individual lines. Every one of those effects is resolved in
/// `OnboardingBranch`; this screen only records the choice.
struct OnboardingExperienceScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow, showsFooter: false) {
            OnboardingTitle(text: OnboardingCopy.Experience.title)
            OnboardingBody(text: OnboardingCopy.Experience.body)
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(OnboardingExperience.allCases, id: \.self) { exp in
                    OnboardingChoiceRow(
                        title: OnboardingCopy.Experience.option(exp),
                        identifier: "onboarding.experience.\(exp.rawValue)"
                    ) {
                        flow.choose(exp: exp)
                    }
                }
            }
        } actions: {
            EmptyView()
        }
    }
}
