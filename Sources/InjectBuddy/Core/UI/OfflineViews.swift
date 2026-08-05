import SwiftUI

// ─── Offline UI ──────────────────────────────────────────────────────────────
// Two distinct connectivity surfaces, mirroring the web's 27-offline-default.png
// without copying its dark web-chrome:
//   • OfflineBanner — a small passive pill, mounted once in MainShell above the
//     tab bar. Shows on EVERY screen (calculators included) purely as a status
//     indicator; it never blocks input, so offline calculator use is unaffected.
//   • OfflineView — the full blocking state a NETWORKED screen swaps in when it
//     has nothing cached to show and the device is offline. Built on
//     EmptyStateView so it stays visually consistent with every other empty/error
//     state, with a Retry action instead of the web's "Go to homepage" (iOS
//     already has real tabs/back-nav, so re-attempting the load is the more
//     useful native affordance).

struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.footnote.weight(.semibold))
            Text("You're offline")
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.danger, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You're offline")
    }
}

struct OfflineView: View {
    /// Re-run the screen's load; wired to the calling screen's `reload()`.
    let retry: () -> Void

    var body: some View {
        EmptyStateView(
            systemImage: "wifi.slash",
            title: "You're offline",
            message: "No internet connection detected. Any calculator you've visited before is still available — just navigate back to it.",
            actionTitle: "Retry",
            action: retry
        )
    }
}
