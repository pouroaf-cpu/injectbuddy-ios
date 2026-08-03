import SwiftUI

// ─── OnboardingPreview ───────────────────────────────────────────────────────
//
// A second APP TARGET in the same Xcode project (see project.yml). It exists for
// one reason, from SPEC §1:
//
//   "I think we make this as a separate app, its own folder inside the ios, and
//    then we can test it without a login. All we need is the onboarding screens."
//
// **NO AUTH. NO `RootView` GATE. NO SUPABASE. NO NETWORK.** Launch it and you
// are on screen 1. Sign-in is the measured bottleneck on this rig (~20–25
// signed-in checks/hour against an 11s no-op rebuild); this target removes it
// from the loop entirely.
//
// **Screen 1's premise is a user who has ALREADY SIGNED UP.** SPEC §6: "Auth is
// assumed complete, not absent. The target contains no auth because it does not
// need any, not because the flow happens before sign-up."
//
// This target must never gain a dependency on `Core/Backend`, `Core/Auth` or
// anything in `Features/`. Its source paths in project.yml are exactly
// `Sources/OnboardingPreview`, `Sources/OnboardingKit` and
// `Sources/InjectBuddy/Core/Theme` — if a build error asks for a fourth, that is
// a finding about the boundary, not a reason to add one.

@main
struct OnboardingPreviewApp: App {

    /// **THE NO-OP SINK.** It writes nothing, by design — SPEC §1 and §6. See
    /// the banner on `OnboardingSink` before replacing it with anything.
    @StateObject private var flow = OnboardingFlow(sink: NoOpOnboardingSink())

    var body: some Scene {
        WindowGroup {
            OnboardingFlowView(flow: flow)
                // The app is LIGHT ONLY. `UIUserInterfaceStyle: Light` in
                // project.yml is the mechanism; this is belt-and-braces, exactly
                // as InjectBuddyApp does it.
                .preferredColorScheme(.light)
        }
    }
}
