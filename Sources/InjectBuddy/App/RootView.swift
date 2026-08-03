import SwiftUI

// ─── RootView ────────────────────────────────────────────────────────────────
// The auth gate. Unauthed → AuthFlow; authed → MainShell (which opens on the
// Dashboard). A brief launch state covers the keychain session restore.

struct RootView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore

    /// Nil while the welcome screen is showing; set when a CTA picks a form.
    @State private var authMode: AuthFlowView.Mode?

    #if DEBUG
    /// DEBUG ONLY. Set when the bypass gives up and hands the screen back to the
    /// real gate, so a failed bypass is recoverable on the rig instead of a dead
    /// end. Does not exist in a Release build.
    @State private var debugBypassHandedOver = false
    #endif

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
                signedOutContent
                    .transition(.opacity)
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

    // ─── The auth gate ───────────────────────────────────────────────────────
    //
    //  THE ONE PLACE A BUILD DECIDES WHETHER THE SIGN-IN SCREEN IS SHOWN, AND IT
    //  DECIDES AT COMPILE TIME. The `#else` below is the Release path, verbatim
    //  what shipped before the bypass existed, and it is the ONLY branch a Release
    //  build compiles. There is no flag, no environment variable and no setting
    //  that reaches it — a runtime lever could be flipped in a shipped binary, and
    //  this must not be flippable.
    //
    //  Verify by eye: `#if DEBUG` … `#else` … `#endif` with `realSignInGate` on the
    //  `#else` side, and every other bypass symbol confined to
    //  `Core/Auth/DebugAuthBypass.swift`, a file that is `#if DEBUG` from its first
    //  line to its last. Verify for real: BATCH.md's PRE-SHIP CHECKLIST — launch a
    //  Release build and see `AuthFlow`.
    //
    @ViewBuilder
    private var signedOutContent: some View {
        #if DEBUG
        // Boot straight past the gate. A keychain session never reaches here at all
        // (AuthStore restores it and the phase is already `.signedIn`); this is the
        // no-session case, which signs in from the QA credentials. One attempt per
        // launch — after that the real gate returns, so signing out in a debug build
        // is still a thing you can test.
        if debugBypassHandedOver || DebugAuthBypass.hasAttemptedThisLaunch {
            realSignInGate
        } else {
            DebugAuthBypassView(onUseRealSignIn: { debugBypassHandedOver = true })
        }
        #else
        realSignInGate
        #endif
    }

    /// The real, shipping gate. Deliberately OUTSIDE the `#if` so it type-checks in
    /// every configuration — a Release-only view would rot unnoticed in a tree where
    /// every test runs the debug build.
    @ViewBuilder
    private var realSignInGate: some View {
        if let mode = authMode {
            AuthFlowView(initialMode: mode)
        } else {
            WelcomeView(
                onCreateAccount: { authMode = .signUp },
                onSignIn: { authMode = .login }
            )
        }
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
