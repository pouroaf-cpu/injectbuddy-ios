import SwiftUI

// ─── SCREEN 9 · paywall (bar 100%) ───────────────────────────────────────────
//
// The longest screen in the flow, and the one with the most to get wrong.
//
//   • The headline is `segment`'s (four variants).
//   • The body's OPENER is `skipped`'s (SPEC §3 rule 6) — fewer than two skips
//     reads "— protocol set, reminders on", otherwise "— your protocol, set up
//     your way". The sentence is composed in `OnboardingCopy.Paywall.body`, not
//     concatenated here: a view never assembles copy.
//   • **`$X/mo` STAYS THE LITERAL TOKEN.** SPEC §6 — the owner has not set the
//     price. It comes in through `OnboardingCopy.priceToken` and there is no
//     number anywhere in this file.
//   • No StoreKit. SPEC §6 — choosing a plan sets `state.plan` and routes; it
//     buys nothing.
//
// All three CTAs are in the pinned footer, not just the primary one: they are
// three branches of one decision, and a user who cannot see "Not now" without
// scrolling is being pushed rather than asked.

struct OnboardingPaywallScreen: View {
    @ObservedObject var flow: OnboardingFlow

    var body: some View {
        OnboardingScreenScaffold(flow: flow) {
            if let segment = flow.state.segment {
                OnboardingTitle(text: OnboardingCopy.Paywall.headline(segment))
            }
            OnboardingBody(text: OnboardingBranch.paywallBody(skipped: flow.state.skipped))

            founderNote
            splitRows
            timeline
        } actions: {
            OnboardingPrimaryButton(
                title: OnboardingCopy.Paywall.ctaTrial,
                identifier: "onboarding.paywall.trial"
            ) {
                flow.choose(plan: .trial)
            }
            OnboardingSecondaryButton(
                title: OnboardingCopy.Paywall.ctaPaid,
                identifier: "onboarding.paywall.paid"
            ) {
                flow.choose(plan: .paid)
            }
            OnboardingGhostButton(
                title: OnboardingCopy.Paywall.ctaDecline,
                identifier: "onboarding.paywall.decline"
            ) {
                flow.choose(plan: .declined)
            }
        }
    }

    // MARK: - The founder note
    //
    // SPEC §4: "Founder note, with a photo of Pou." The photo is one of the
    // fifteen illustrations and does not exist, so it is a labelled placeholder
    // like the rest.

    private var founderNote: some View {
        OnboardingCard(identifier: "onboarding.paywall.founder") {
            if let art = OnboardingIllustration.forStep(.paywall) {
                OnboardingIllustrationPlaceholder(illustration: art)
            }
            Text(OnboardingCopy.attributed(OnboardingCopy.Paywall.founderQuote))
                .font(.callout.italic())
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(OnboardingCopy.Paywall.founderAttribution)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(OnboardingCopy.Accessibility.founderNote)
    }

    // MARK: - THIS APP / ALWAYS FREE

    private var splitRows: some View {
        VStack(spacing: Theme.Spacing.sm) {
            splitRow(
                label: OnboardingCopy.Paywall.thisAppLabel,
                body: OnboardingCopy.Paywall.thisAppBody,
                identifier: "onboarding.paywall.thisApp")
            splitRow(
                label: OnboardingCopy.Paywall.alwaysFreeLabel,
                body: OnboardingCopy.Paywall.alwaysFreeBody,
                identifier: "onboarding.paywall.alwaysFree")
        }
    }

    private func splitRow(label: String, body: String, identifier: String) -> some View {
        OnboardingCard(identifier: identifier) {
            Text(label)
                .font(Theme.Typeface.eyebrow)
                .foregroundStyle(Theme.tealTextStrong)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - The trial timeline
    //
    // SPEC §4 writes it with arrows — `TODAY no charge` → `DAY 5 we remind you`
    // → `DAY 7 billed · cancel anytime`. It is drawn as a VERTICAL sequence with
    // a drawn glyph between the rows, because a horizontal one has to shrink or
    // shear its labels the moment the text grows, and D4 forbids the shear.
    // The glyph is decoration and is hidden from the accessibility tree (D3).

    private var timeline: some View {
        OnboardingCard(identifier: "onboarding.paywall.timeline") {
            ForEach(Array(OnboardingCopy.Paywall.timeline.enumerated()), id: \.offset) { index, entry in
                if index > 0 {
                    Image(systemName: "arrow.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.tealTextStrong)
                        .accessibilityHidden(true)
                }
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(entry.label)
                        .font(Theme.Typeface.eyebrow)
                        .foregroundStyle(Theme.tealTextStrong)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.detail)
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(OnboardingCopy.Accessibility.timeline)
    }
}
