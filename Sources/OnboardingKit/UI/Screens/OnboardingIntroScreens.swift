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
    @FocusState private var nameFocused: Bool

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            if let art = OnboardingIllustration.forStep(.welcome) {
                OnboardingIllustrationPlaceholder(illustration: art)
                    .onboardingReveal(0, step: .welcome)
            }

            // ⚠️ THE CONGRATULATION IS A PLACEHOLDER AND IS DRAWN AS ONE.
            // Same warning-coloured dashed treatment as the missing art, so a screenshot
            // of screen 1 shows a placeholder the way a benefit screen already does —
            // rather than showing a sentence someone might take for the owner's.
            OnboardingPlaceholderLine(text: OnboardingCopy.Welcome.titlePlaceholder)
                .onboardingReveal(1, step: .welcome)

            OnboardingTitle(text: OnboardingCopy.Welcome.prompt)
                .onboardingReveal(2, step: .welcome)

            OnboardingNameField(
                label: OnboardingCopy.Welcome.fieldLabel,
                optionalNote: OnboardingCopy.Welcome.fieldOptional,
                placeholder: OnboardingCopy.Welcome.fieldPlaceholder,
                maxLength: OnboardingCopy.Welcome.nameMaxLength,
                text: $flow.state.name,
                isFocused: $nameFocused,
                onSubmit: { flow.advance() }
            )
            .onboardingReveal(3, step: .welcome)
        } actions: {
            // **NOT disabled on empty, and that is the reversal.** The field is optional
            // with an explicit Skip: across 89 live profiles `display_name` is 89/89 while
            // `nickname` is 1/89, so almost every real user already has a usable name
            // before we ask. A required field would be a wall in front of a question we
            // mostly know the answer to. SPEC §3.1.
            OnboardingPrimaryButton(title: OnboardingCopy.Welcome.cta) {
                flow.advance()
            }
            OnboardingGhostButton(title: OnboardingCopy.Welcome.ctaSkip) {
                // Skipping CLEARS the field rather than leaving a half-typed name to
                // become the personalisation key. Trimmed-empty is absent either way, but
                // this makes the intent explicit rather than relying on the trim.
                flow.state.name = ""
                flow.advance()
            }
        }
        .onAppear { nameFocused = true }        // keyboard up on appear, SPEC §3.1
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
            // PLACEMENT 1 of 5. The view asks the flow for the line; it does not pick
            // between two strings and it never concatenates a name onto one.
            OnboardingTitle(text: flow.pathwayTitle)
                .onboardingReveal(0, step: .pathway)
            OnboardingBody(text: OnboardingCopy.Pathway.body)
                .onboardingReveal(1, step: .pathway)
            VStack(spacing: Theme.Spacing.md) {
                // Order comes from `OnboardingSegment.allCases`, which is where
                // the model says it lives — not from a list retyped in a view.
                ForEach(Array(OnboardingSegment.allCases.enumerated()), id: \.element) { index, segment in
                    OnboardingChoiceRow(
                        title: OnboardingCopy.Pathway.option(segment),
                        isSelected: flow.state.segment == segment,
                        identifier: "onboarding.pathway.\(segment.rawValue)"
                    ) {
                        flow.choose(segment: segment)
                    }
                    .onboardingReveal(2 + index, step: .pathway)
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
                .onboardingReveal(0, step: .experience)
            // PLACEMENT 2 of 5 — the line that is already about how we address the user.
            OnboardingBody(text: flow.experienceBody)
                .onboardingReveal(1, step: .experience)
            VStack(spacing: Theme.Spacing.md) {
                ForEach(Array(OnboardingExperience.allCases.enumerated()), id: \.element) { index, exp in
                    OnboardingChoiceRow(
                        title: OnboardingCopy.Experience.option(exp),
                        isSelected: flow.state.exp == exp,
                        identifier: "onboarding.experience.\(exp.rawValue)"
                    ) {
                        flow.choose(exp: exp)
                    }
                    .onboardingReveal(2 + index, step: .experience)
                }
            }
        } actions: {
            EmptyView()
        }
    }
}
