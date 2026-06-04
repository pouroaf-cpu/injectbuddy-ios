import SwiftUI

// ─── RootView ────────────────────────────────────────────────────────────────
// The auth gate. Unauthed → AuthFlow; authed → MainShell (which opens on the
// Dashboard). A brief launch state covers the keychain session restore.

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        ZStack {
            switch auth.phase {
            case .loading:
                LaunchView()
                    .transition(.opacity)
            case .signedOut:
                AuthFlowView()
                    .transition(.opacity)
            case .signedIn:
                MainShell()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.phase)
    }
}

/// Minimal launch / splash shown while the persisted session is restored.
struct LaunchView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                BrandMark()
                ProgressView().tint(Theme.accent)
            }
        }
    }
}

/// The injectbuddy wordmark used on the splash + auth + drawer.
struct BrandMark: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "syringe.fill")
                .foregroundStyle(Theme.accent)
                .font(.title3)
            Text("inject")
                .foregroundStyle(Theme.label)
            + Text("buddy")
                .foregroundStyle(Theme.label).bold()
        }
        .font(.title2)
    }
}
