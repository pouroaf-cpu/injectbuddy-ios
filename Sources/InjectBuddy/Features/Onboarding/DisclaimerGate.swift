import SwiftUI

// ─── DisclaimerGate ──────────────────────────────────────────────────────────
// First-run, full-screen "informational only — not medical advice" acknowledgement.
// Shown once (persisted in SettingsStore.hasAcceptedDisclaimer) before the app is
// usable. Required posture for App Review of a dosage/health tool: the disclaimer is
// prominent and explicitly acknowledged, and the app never presents itself as a
// prescriber or medical device.

struct DisclaimerGate: View {
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                Image(systemName: "exclamationmark.shield")
                    .font(.system(size: 52))
                    .foregroundStyle(Theme.accent)
                Text("Before you start")
                    .font(.title.bold())

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    bullet("InjectBuddy is an informational calculator. Its results are math only — "
                         + "they are not medical advice, a diagnosis, or a prescription.")
                    bullet("Doses, schedules, and conversions are estimates. Always verify with your "
                         + "prescriber or pharmacist before acting on any result.")
                    bullet("Do not start, stop, or change any medication based on this app. In an "
                         + "emergency, contact your local emergency services.")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryLabel)
                .padding(Theme.Spacing.md)
                .card()

                Spacer()

                PrimaryButton(title: "I understand", action: onAccept)
                Text("By continuing you acknowledge the above.")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: 480)
        }
        .interactiveDismissDisabled(true)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "circle.fill").font(.system(size: 5)).padding(.top, 7)
                .foregroundStyle(Theme.accent)
            Text(text)
        }
    }
}
