import SwiftUI

// ─── RootView ────────────────────────────────────────────────────────────────
// The auth gate. Unauthed → AuthFlow; authed → MainShell (which opens on the
// Dashboard). A brief launch state covers the keychain session restore.

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore

    /// Nil while the welcome screen is showing; set when a CTA picks a form.
    @State private var authMode: AuthFlowView.Mode?

    var body: some View {
        ZStack {
            switch auth.phase {
            case .loading:
                // The welcome screen IS the launch state. It is sized to however
                // long auth actually takes — if the session resolves in 200ms this
                // is on screen for 200ms. The animation never gates the phase.
                WelcomeView()
                    .transition(.opacity)
            case .signedOut:
                if let mode = authMode {
                    AuthFlowView(initialMode: mode)
                        .transition(.opacity)
                } else {
                    WelcomeView(
                        onCreateAccount: { authMode = .signUp },
                        onSignIn: { authMode = .login }
                    )
                    .transition(.opacity)
                }
            case .signedIn:
                MainShell()
                    .transition(.opacity)
            }

            // First-run medical disclaimer — gates the whole app until acknowledged.
            if !settings.hasAcceptedDisclaimer {
                DisclaimerGate { settings.hasAcceptedDisclaimer = true }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.phase)
        .animation(.easeInOut(duration: 0.25), value: authMode)
        .animation(.easeInOut(duration: 0.25), value: settings.hasAcceptedDisclaimer)
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
                .foregroundColor(Theme.label)
            + Text("buddy")
                .foregroundColor(Theme.label).bold()
        }
        .font(.title2)
    }
}
