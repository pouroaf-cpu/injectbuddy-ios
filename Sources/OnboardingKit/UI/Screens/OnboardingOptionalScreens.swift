import SwiftUI

// ─── SCREENS 6, 7, 8 ─────────────────────────────────────────────────────────
//
// The three skippable steps — and skipping is not a dead end, it is data: both
// `skipped` reads (SPEC §3 rules 6 and 7) hang off exactly these screens, so a
// Skip here must go through `flow.skip(_:)` and never through `flow.advance()`.

// MARK: - 6 · reminders (bar 84%)

/// SPEC §4: "**The OS permission ask happens here and nowhere earlier** — never
/// on app open."
///
/// ***AND IT IS NOT ASKED IN THIS PASS.*** SPEC §6 puts "the notification
/// permission actually being requested" out of scope. This screen collects the
/// time and records the choice; the day someone wires `UNUserNotificationCenter`
/// up, this is the screen it attaches to and nowhere earlier.
///
/// The spec's body ends with an italic parenthetical — *"(Triggers the OS
/// notification permission ask.)"*. **It stays a comment in the copy file and is
/// deliberately NOT rendered**, pending the owner's ruling: it reads as an
/// instruction to the implementer rather than a line for the user. It is the one
/// place in this flow where §4 text is knowingly not on screen.
struct OnboardingRemindersScreen: View {
    @ObservedObject var flow: OnboardingFlow

    /// Held locally and committed only on accept, so a user who skips does not
    /// silently hand a reminder time to the sink.
    @State private var time: Date = OnboardingRemindersScreen.defaultTime

    /// 9:00am today. A neutral opening position, not a recommendation — the flow
    /// has no opinion about when a dose is due.
    private static var defaultTime: Date {
        Calendar.current.date(
            bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    }

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            OnboardingEyebrow(text: OnboardingCopy.Reminders.note)
            OnboardingTitle(text: OnboardingCopy.Reminders.title)
            OnboardingBody(text: OnboardingCopy.Reminders.body)

            OnboardingCard(identifier: "onboarding.reminders.card") {
                DatePicker(
                    selection: $time,
                    displayedComponents: .hourAndMinute
                ) {
                    Text(OnboardingCopy.Reminders.fieldLabel)
                        .font(Theme.Typeface.cardMeta)
                        .foregroundStyle(Theme.navy)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(Theme.navy)
                .frame(minHeight: Theme.minTarget)
                .accessibilityIdentifier("onboarding.reminders.time")
            }
        } actions: {
            OnboardingPrimaryButton(title: OnboardingCopy.Reminders.ctaAccept) {
                flow.state.reminderTime = time
                flow.advance()
            }
            OnboardingGhostButton(
                title: OnboardingCopy.Reminders.ctaSkip,
                identifier: "onboarding.reminders.skip"
            ) {
                flow.skip(.reminders)
            }
        }
    }
}

// MARK: - 7 · inventory (bar 90%)

struct OnboardingInventoryScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            OnboardingEyebrow(text: OnboardingCopy.Inventory.note)
            OnboardingTitle(text: OnboardingCopy.Inventory.title)
            OnboardingBody(text: OnboardingCopy.Inventory.body)

            OnboardingField(
                label: OnboardingCopy.Inventory.vialCountLabel,
                value: $flow.state.vialCount,
                keyboard: .numberPad,
                identifier: "onboarding.inventory.count")

            OnboardingField(
                label: OnboardingCopy.Inventory.vialSizeLabel,
                value: $flow.state.vialSize,
                keyboard: .decimalPad,
                identifier: "onboarding.inventory.size")
        } actions: {
            OnboardingPrimaryButton(title: OnboardingCopy.Inventory.ctaAccept) {
                flow.advance()
            }
            OnboardingGhostButton(
                title: OnboardingCopy.Inventory.ctaSkip,
                identifier: "onboarding.inventory.skip"
            ) {
                flow.skip(.inventory)
            }
        }
    }
}

// MARK: - 8 · firstDose (bar 97%)

/// SPEC §3: "the aha moment — core value **before** the paywall." The body is
/// `exp`-dependent (rule 5) and is resolved by `OnboardingBranch`, not here.
struct OnboardingFirstDoseScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            if let art = OnboardingIllustration.forStep(.firstDose) {
                OnboardingIllustrationPlaceholder(illustration: art)
            }
            OnboardingTitle(text: OnboardingCopy.FirstDose.title)
            OnboardingBody(text: flow.branch.firstDoseBody)   // SPEC §3 rule 5
        } actions: {
            OnboardingPrimaryButton(title: OnboardingCopy.FirstDose.ctaAccept) {
                flow.advance()
            }
            OnboardingGhostButton(
                title: OnboardingCopy.FirstDose.ctaSkip,
                identifier: "onboarding.firstDose.skip"
            ) {
                flow.skip(.firstDose)
            }
        }
    }
}
