import SwiftUI

// ─── THE ROOT VIEW ───────────────────────────────────────────────────────────
//
// `OnboardingPreview`'s root view IS this. SPEC §1: "Launch it in the simulator
// and you are on screen 1."
//
// ***THE SCREENS DO NOT EXIST YET.*** This pass is the foundation — the target,
// the folder, the copy file and the state machine. What `stepContent` renders
// today is a SCAFFOLD: it proves the seams line up and it makes the target
// buildable and walkable, and it is not the design.
//
// THE SECOND PASS REPLACES `stepContent` ARM BY ARM. The switch is exhaustive
// with no `default`, so it is also the checklist: every one of the thirteen
// screens has a line here that has to be visited.
//
// Two things the screens pass must not undo:
//   • **No string literals in views.** Every word on screen comes from
//     `OnboardingCopy`. If a word is missing, add it there.
//   • **D5** — the primary action must be reachable without scrolling at every
//     text size, and so must the input it commits. The scaffold does not
//     establish this; `setup` (four fields, a CTA and a variant line) is the
//     known risk and is the screens pass's problem to solve and measure.

struct OnboardingFlowView: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                stepContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.Spacing.md)
            }
        }
        .background(Theme.canvas.ignoresSafeArea())
    }

    // MARK: - Header: progress bar + back + the debug restart

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                if flow.canGoBack {
                    Button(OnboardingCopy.Debug.back) { flow.back() }
                }
                Spacer()
                // Debug affordance only — SPEC §3. Never in the real app.
                Button(OnboardingCopy.Debug.restart) { flow.restart() }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.navy)

            // SPEC §3 — the bar starts at 25% (endowed progress) and the values
            // are exact. `nil` on the two end states, which carry no bar.
            if let fraction = flow.barFraction {
                ProgressView(value: fraction)
                    .tint(Theme.accent)
                    .accessibilityIdentifier("onboarding.progress")
                    .accessibilityValue("\(flow.barPercent ?? 0)")
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: - The thirteen screens
    //
    // SCAFFOLD. Replace one arm at a time.

    @ViewBuilder
    private var stepContent: some View {
        switch flow.step {

        case .welcome:
            scaffold(
                title: OnboardingCopy.Welcome.title,
                body: OnboardingCopy.Welcome.body,
                illustration: OnboardingIllustration.forStep(.welcome),
                actions: [.init(OnboardingCopy.Welcome.cta) { flow.advance() }])

        case .pathway:
            scaffold(
                title: OnboardingCopy.Pathway.title,
                body: OnboardingCopy.Pathway.body,
                actions: OnboardingSegment.allCases.map { segment in
                    .init(OnboardingCopy.Pathway.option(segment)) { flow.choose(segment: segment) }
                })

        case .experience:
            scaffold(
                title: OnboardingCopy.Experience.title,
                body: OnboardingCopy.Experience.body,
                actions: OnboardingExperience.allCases.map { exp in
                    .init(OnboardingCopy.Experience.option(exp)) { flow.choose(exp: exp) }
                })

        case .benefit1, .benefit2, .benefit3:
            benefitScaffold

        case .setup:
            setupScaffold

        case .reminders:
            scaffold(
                title: OnboardingCopy.Reminders.title,
                note: OnboardingCopy.Reminders.note,
                body: OnboardingCopy.Reminders.body,
                actions: [
                    .init(OnboardingCopy.Reminders.ctaAccept) { flow.advance() },
                    .init(OnboardingCopy.Reminders.ctaSkip) { flow.skip(.reminders) },
                ])

        case .inventory:
            scaffold(
                title: OnboardingCopy.Inventory.title,
                note: OnboardingCopy.Inventory.note,
                body: OnboardingCopy.Inventory.body,
                actions: [
                    .init(OnboardingCopy.Inventory.ctaAccept) { flow.advance() },
                    .init(OnboardingCopy.Inventory.ctaSkip) { flow.skip(.inventory) },
                ])

        case .firstDose:
            scaffold(
                title: OnboardingCopy.FirstDose.title,
                body: flow.branch.firstDoseBody,                     // SPEC §3 rule 5
                illustration: OnboardingIllustration.forStep(.firstDose),
                actions: [
                    .init(OnboardingCopy.FirstDose.ctaAccept) { flow.advance() },
                    .init(OnboardingCopy.FirstDose.ctaSkip) { flow.skip(.firstDose) },
                ])

        case .paywall:
            paywallScaffold

        case .dashboard:
            dashboardScaffold

        case .locked:
            scaffold(
                title: OnboardingCopy.Locked.title,
                body: OnboardingCopy.Locked.body,
                actions: [
                    .init(OnboardingCopy.Locked.cta) { flow.seePlansAgain() },
                    // SPEC §1 — the loop IS the end state. No interstitial.
                    .init(OnboardingCopy.Debug.finishAndLoop) { flow.finish() },
                ])
        }
    }

    private var benefitScaffold: some View {
        let benefit = flow.currentBenefit
        let index = flow.benefitIndex(of: flow.step).map { $0 - 1 } ?? 0
        let art = flow.state.segment.flatMap {
            OnboardingIllustration.forBenefit(segment: $0, index: index)
        }
        var actions: [ScaffoldAction] = [
            // SPEC §3 rule 1 — "Set me up" on the fast lane, "Next" otherwise.
            .init(flow.branch.benefitCTA) { flow.advance() }
        ]
        // SPEC §3 rule 1 — the fast lane shows NO Skip. Rule 2 — the others do.
        if flow.branch.benefitShowsSkip {
            actions.append(.init(OnboardingCopy.Benefits.ctaSkip) { flow.skipBenefits() })
        }
        return scaffold(
            title: benefit?.title ?? "",
            body: benefit?.body,
            illustration: art,
            actions: actions)
    }

    private var setupScaffold: some View {
        var actions: [ScaffoldAction] = []
        // SPEC §3 rule 4 — up front, `.adv` only.
        if flow.branch.setupShowsAddAnotherCompoundUpFront {
            actions.append(.init(OnboardingCopy.Setup.addAnotherCompound) {})
        }
        actions.append(.init(OnboardingCopy.Setup.cta) { flow.advance() })
        return scaffold(
            title: OnboardingCopy.Setup.title,
            note: OnboardingCopy.Setup.note,
            body: OnboardingCopy.Setup.body,
            // SPEC §3 rule 3 — the reassurance line, `.first` only.
            extraLine: flow.branch.setupExtraLine,
            fields: [
                OnboardingCopy.Setup.unitsLabel,
                OnboardingCopy.Setup.compoundLabel,
                OnboardingCopy.Setup.doseLabel,
                OnboardingCopy.Setup.frequencyLabel,
            ],
            actions: actions)
    }

    private var paywallScaffold: some View {
        scaffold(
            title: flow.state.segment.map(OnboardingCopy.Paywall.headline) ?? "",
            // SPEC §3 rule 6 — the opener varies on how much was skipped.
            body: OnboardingBranch.paywallBody(skipped: flow.state.skipped),
            illustration: OnboardingIllustration.forStep(.paywall),
            extraLine: OnboardingCopy.Paywall.founderQuote,
            fields: OnboardingCopy.Paywall.timeline.map { "\($0.label) \($0.detail)" },
            actions: [
                .init(OnboardingCopy.Paywall.ctaTrial) { flow.choose(plan: .trial) },
                .init(OnboardingCopy.Paywall.ctaPaid) { flow.choose(plan: .paid) },
                .init(OnboardingCopy.Paywall.ctaDecline) { flow.choose(plan: .declined) },
            ])
    }

    private var dashboardScaffold: some View {
        scaffold(
            title: OnboardingCopy.Dashboard.title,
            body: OnboardingBranch.dashboardMessage(plan: flow.state.plan),
            // SPEC §3 rule 7 — "reminder set ✓" / "set a reminder?"
            extraLine: OnboardingBranch.dashboardNextDose(skipped: flow.state.skipped),
            // SPEC §1 — the loop IS the end state. No interstitial.
            actions: [.init(OnboardingCopy.Debug.finishAndLoop) { flow.finish() }])
    }

    // MARK: - Scaffold primitives (provisional — the screens pass owns the design)

    struct ScaffoldAction: Identifiable {
        let id = UUID()
        let title: String
        let action: () -> Void
        init(_ title: String, action: @escaping () -> Void) {
            self.title = title
            self.action = action
        }
    }

    private func scaffold(
        title: String,
        note: String? = nil,
        body: String? = nil,
        illustration: OnboardingIllustration? = nil,
        extraLine: String? = nil,
        fields: [String] = [],
        actions: [ScaffoldAction]
    ) -> some View {
        // No `lineLimit` anywhere here, deliberately: a value, unit or screen
        // title that shears at large text was the worst finding of the audit.
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.largeTitle.weight(.heavy))
                .foregroundStyle(Theme.inkNavy)
                .accessibilityIdentifier("onboarding.title")

            if let note {
                Text(note)
                    .font(Theme.Typeface.eyebrow)
                    .foregroundStyle(Theme.tealTextStrong)
            }
            if let illustration {
                OnboardingIllustrationPlaceholder(illustration: illustration)
            }
            if let body {
                Text(OnboardingCopy.attributed(body))
                    .font(.body)
                    .foregroundStyle(Theme.ink)
            }
            if let extraLine {
                Text(OnboardingCopy.attributed(extraLine))
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryLabel)
            }
            ForEach(fields, id: \.self) { field in
                Text(field)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondaryLabel)
            }
            ForEach(actions) { action in
                Button(action.title, action: action.action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .frame(minHeight: Theme.minTarget)
            }
        }
    }
}
