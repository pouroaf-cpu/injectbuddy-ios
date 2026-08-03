import SwiftUI

// ─── SCREEN 5 · setup (bar 76%) ──────────────────────────────────────────────
//
// **THE D5 RISK ON THIS FLOW, NAMED IN THE SPEC ITSELF.** SPEC §7: "The setup
// screen is the risk — four fields plus a CTA plus a variant line."
//
// What is structurally guaranteed here: the CTA is in the pinned footer, so
// "This is my protocol" is on screen at every text size, full stop. What is NOT
// guaranteed by structure is the second half of D5 — "and so is the input it
// commits" — because four inputs plus a title plus body copy cannot all fit at
// the largest accessibility sizes on any phone. That half is a measurement, and
// it is measured in the sweep rather than asserted here.
//
// Two `exp` variants land on this screen, and neither is decided here:
//   • rule 3 — `.first` gets the reassurance line (`flow.branch.setupExtraLine`)
//   • rule 4 — `.adv` gets "＋ Add another compound" UP FRONT
//
// The numeric fields are `String`. SPEC §1: "No rounding on the way in. A user
// entering 180 lb must get 180 lb back." Nothing between the keyboard and the
// sink coerces the value.

struct OnboardingSetupScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            OnboardingEyebrow(text: OnboardingCopy.Setup.note)
            OnboardingTitle(text: OnboardingCopy.Setup.title)
            OnboardingBody(text: OnboardingCopy.Setup.body)

            // SPEC §3 rule 3 — `.first` only.
            if let extraLine = flow.branch.setupExtraLine {
                OnboardingSupportingLine(
                    text: extraLine,
                    identifier: "onboarding.setup.reassurance")
            }

            OnboardingUnitPicker(
                label: OnboardingCopy.Setup.unitsLabel,
                selection: $flow.state.units)

            OnboardingField(
                label: OnboardingCopy.Setup.compoundLabel,
                value: $flow.state.compound,
                identifier: "onboarding.setup.compound")

            // SPEC §3 rule 4 — up front, `.adv` only. It appends a compound
            // rather than pretending to: the fast lane's whole premise is a user
            // who already runs more than one.
            // Drawn as an inline, leading-aligned action rather than a bordered
            // block: measured at default size on 2026-08-03, the full-width
            // version was the heaviest thing on the form after the CTA itself
            // and read as the screen's main action, which it is not.
            if flow.branch.setupShowsAddAnotherCompoundUpFront {
                OnboardingGhostButton(
                    title: OnboardingCopy.Setup.addAnotherCompound,
                    identifier: "onboarding.setup.addCompound",
                    leading: true
                ) {
                    flow.state.extraCompounds.append("")
                }
            }

            ForEach(flow.state.extraCompounds.indices, id: \.self) { index in
                OnboardingField(
                    label: OnboardingCopy.Setup.compoundLabel,
                    value: $flow.state.extraCompounds[index],
                    identifier: "onboarding.setup.extraCompound.\(index)")
            }

            OnboardingField(
                label: OnboardingCopy.Setup.doseLabel,
                value: $flow.state.dose,
                keyboard: .decimalPad,
                identifier: "onboarding.setup.dose")

            OnboardingField(
                label: OnboardingCopy.Setup.frequencyLabel,
                value: $flow.state.frequency,
                identifier: "onboarding.setup.frequency")
        } actions: {
            OnboardingPrimaryButton(title: OnboardingCopy.Setup.cta) {
                flow.advance()
            }
        }
    }
}
