import Foundation

// ─── THE SINK SEAM ───────────────────────────────────────────────────────────
//
//  ╔═══════════════════════════════════════════════════════════════════════╗
//  ║  READ THIS BEFORE YOU WRITE AN IMPLEMENTATION OF THIS PROTOCOL.       ║
//  ║                                                                       ║
//  ║  docs/SPEC-ONBOARDING.md IS THE ROUTE AND THE COPY. IT IS NOT THE     ║
//  ║  WRITE CONTRACT. The write contract is:                                ║
//  ║      docs/WELCOME-AND-ONBOARDING.md §3   (the five-step flow that      ║
//  ║                                           writes `public.profiles`)    ║
//  ║      docs/DATA-CONTRACT.md              (authoritative for what the    ║
//  ║                                           database accepts)            ║
//  ║                                                                       ║
//  ║  RLS REFUSES A BAD WRITE SILENTLY: no error, no row, and a call site   ║
//  ║  that only checks "did not throw" cannot tell the difference. A sink   ║
//  ║  built from the onboarding spec alone WILL LOOK LIKE IT WORKS.        ║
//  ║                                                                       ║
//  ║  The three constraints that are in NEITHER the onboarding spec NOR     ║
//  ║  the wireframes it came from:                                          ║
//  ║   1. A skipped step writes the DEFAULT, never a null. Three `profiles` ║
//  ║      columns are NOT NULL and `logging_interests` is a NOT NULL array; ║
//  ║      steps 2–5 are all skippable.                                      ║
//  ║   2. `onboarding_completed_at` is set ONLY on completion. Setting it   ║
//  ║      early strands the user; setting it never loops them.              ║
//  ║   3. No rounding on the way in. 180 lb in, 180 lb back. Store metric   ║
//  ║      always; the unit preference is DISPLAY ONLY.                      ║
//  ║                                                                       ║
//  ║  Also: iOS writes to Supabase directly via PostgREST and never calls   ║
//  ║  /api/dosages. `user_id` must be present on every write or RLS refuses ║
//  ║  it silently.                                                          ║
//  ╚═══════════════════════════════════════════════════════════════════════╝
//
// SPEC §1: "The flow writes nothing. It fills an in-memory `OnboardingState`
// and hands it to an `OnboardingSink` protocol at the end. The preview target's
// sink is a no-op that prints. The real sink comes later and is out of scope."
//
// SPEC §6 lists "writing anything to Supabase" as explicitly NOT in this pass.
//
// **A real sink must live OUTSIDE `Sources/OnboardingKit/`.** This folder must
// not depend on `Core/Backend` — the whole point of the boundary. The real app
// injects its own conforming type when it mounts the flow.

/// The single seam through which the flow's collected state leaves the flow.
///
/// Called exactly once per completed walk-through, immediately before the flow
/// resets and loops back to screen 1.
protocol OnboardingSink: AnyObject {

    /// - Parameters:
    ///   - state: everything collected. Fields the user skipped are at their
    ///     initial value, NOT null-in-the-database — translating "skipped" to
    ///     "default" is the sink's job and is spelled out in
    ///     `docs/WELCOME-AND-ONBOARDING.md` §3.
    ///   - endState: which of the two terminals the user reached.
    func onboardingDidFinish(_ state: OnboardingState, at endState: OnboardingEndState)
}

// ─── THE PREVIEW'S SINK ──────────────────────────────────────────────────────

/// **NOT A REAL SINK. IT WRITES NOTHING AND IT NEVER WILL.**
///
/// This is the `OnboardingPreview` target's sink and the deliberate reason
/// nothing can go wrong in this pass. It prints and returns.
///
/// If you are here because you want persistence: **do not add it to this type.**
/// Write a new type, outside `Sources/OnboardingKit/`, after reading the banner
/// at the top of this file. Making this one write would put a Supabase
/// dependency inside `OnboardingKit` and break the boundary in the same commit
/// that broke the write contract.
final class NoOpOnboardingSink: OnboardingSink {

    /// Every completion this sink has been handed, in order. In memory, for the
    /// preview's own debugging — it is not persistence and it does not survive
    /// the process.
    private(set) var completions: [(state: OnboardingState, endState: OnboardingEndState)] = []

    init() {}

    func onboardingDidFinish(_ state: OnboardingState, at endState: OnboardingEndState) {
        completions.append((state, endState))
        print("""
        [OnboardingPreview] NO-OP SINK — nothing was written, by design.
          endState: \(endState.rawValue)
          segment:  \(state.segment.map(\.rawValue) ?? "nil")
          exp:      \(state.exp.map(\.rawValue) ?? "nil")
          plan:     \(state.plan.map(\.rawValue) ?? "nil")
          skipped:  \(state.skipped.map(\.rawValue).sorted().joined(separator: ", "))
          units:    \(state.units.map(\.rawValue) ?? "nil")
          compound: \(state.compound)  dose: \(state.dose)  frequency: \(state.frequency)
          extras:   \(state.extraCompounds)
          reminder: \(state.reminderTime.map(String.init(describing:)) ?? "nil")
          vials:    \(state.vialCount) x \(state.vialSize)
        """)
    }
}
