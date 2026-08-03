// ─── DebugAuthBypass ─────────────────────────────────────────────────────────
//
//  THIS ENTIRE FILE IS INSIDE `#if DEBUG`. In a Release build it compiles to
//  nothing at all — no type, no symbol, no dead branch, nothing to flip. That is
//  deliberate and it is the safety property: if this leaks to Release we ship an
//  app anyone can open as someone else, and every test we own runs the debug
//  build, so nothing in the suite would catch it. See BATCH.md PRE-SHIP
//  CHECKLIST — one Release launch, `AuthFlow` must still be there.
//
//  A reader verifies Release is unaffected in two greps and no reasoning:
//
//      grep -n "if DEBUG"  Sources/InjectBuddy/Core/Auth/DebugAuthBypass.swift  → line 1
//      grep -n "endif"     Sources/InjectBuddy/Core/Auth/DebugAuthBypass.swift  → last line
//
//  and in RootView, `signedOutContent` is a `#if DEBUG` / `#else` pair whose
//  `#else` is the untouched gate.
//
//  WHY A BYPASS AND NOT "REMOVE AUTH": the app's data is RLS-scoped to
//  `auth.uid()`. An app with no session has no rows and every write fails, which
//  would make the write path — the ship — untestable at the exact moment it
//  matters. So this bypasses the sign-in GATE and keeps the SESSION.
//
#if DEBUG

import SwiftUI

@MainActor
enum DebugAuthBypass {

    /// One auto-sign-in per app launch. After that the real gate comes back, so
    /// signing out in a debug build actually signs you out instead of being
    /// instantly undone by this.
    static var hasAttemptedThisLaunch = false

    /// The credentials, and the whole answer to "where do they come from".
    ///
    /// They come from **this process's own environment** — `QA_EMAIL` /
    /// `QA_PASSWORD` — and from nowhere else. Nothing is added to the repo, to
    /// `Config/Secrets.xcconfig`, or to `Info.plist`, because anything in the
    /// xcconfig lands in the plist of BOTH configurations (`project.yml` points
    /// Debug and Release at the same file) and would ship real credentials
    /// inside the binary. This route puts them in RAM of a debug process only.
    ///
    /// Who sets them:
    ///
    /// * **Under XCUITest** — already, today, with no change to any test. Every
    ///   signed-in suite does `app.launchEnvironment["QA_EMAIL"] = email` /
    ///   `["QA_PASSWORD"] = password` in `setUpWithError` (seven files:
    ///   AddFlowToDoseLog, CalculatorWiring, CalculatorLinkWithdrawal,
    ///   DynamicTypeTruncation, LeafOverlap, PinnedBarReachability,
    ///   ProbeAttachment). The runner reads them from its own environment, which
    ///   is where `TEST_RUNNER_QA_EMAIL` / `TEST_RUNNER_QA_PASSWORD` arrive after
    ///   `xcodebuild` strips the prefix. The app has never read them. Now it does.
    ///
    /// * **Launching by hand** — `simctl` forwards `SIMCTL_CHILD_`-prefixed host
    ///   variables to the launched process with the prefix stripped:
    ///
    ///       source .env.local
    ///       SIMCTL_CHILD_QA_EMAIL="$DEVTOOLS_TEST_EMAIL" \
    ///       SIMCTL_CHILD_QA_PASSWORD="$DEVTOOLS_TEST_PASSWORD" \
    ///       xcrun simctl launch --console 1481D20C-A6CB-4A05-8173-33586B374B28 \
    ///         com.injectbuddy.ios
    ///
    ///   Same prefix-stripping shape as `TEST_RUNNER_`, and the same trap: get the
    ///   prefix wrong and the variable silently never arrives. That is exactly why
    ///   the failure path below is loud (`RULES.md` §5.26 / P4).
    ///
    /// Returns nil when either is missing or empty — the loud path, never a
    /// silent landing on a signed-out app.
    static func credentials() -> (email: String, password: String)? {
        let env = ProcessInfo.processInfo.environment
        let email = env["QA_EMAIL"] ?? ""
        let password = env["QA_PASSWORD"] ?? ""
        guard !email.isEmpty, !password.isEmpty else { return nil }
        return (email, password)
    }

    /// Distinctive prefix so the line is greppable in `simctl launch --console`
    /// output and in the Xcode console.
    static func log(_ message: String) {
        NSLog("[DEBUG-AUTH-BYPASS] %@", message)
    }

    /// Email with the local part masked — the log must never carry a usable
    /// credential, and a screenshot of this screen must be safe to attach.
    static func masked(_ email: String) -> String {
        guard let at = email.firstIndex(of: "@") else { return "•••" }
        return "•••" + email[at...]
    }
}

// ─── DebugAuthBypassView ─────────────────────────────────────────────────────
// Shown in place of the sign-in gate in a debug build. It is a status screen, not
// a form: it reports what the bypass is doing and, when it cannot get a session,
// it says so at full volume. A bypass that silently lands on an empty signed-out
// app looks exactly like the app being broken and costs somebody an hour.

struct DebugAuthBypassView: View {

    /// Hands control back to the real gate. Only ever moves toward MORE auth,
    /// never less, and only exists in a debug build.
    var onUseRealSignIn: () -> Void

    @EnvironmentObject private var auth: AuthStore

    private enum Status: Equatable {
        case signingIn(String)      // masked email
        case failed(reason: String, detail: String)
    }

    @State private var status: Status = .signingIn("")

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    banner
                    switch status {
                    case .signingIn(let masked):
                        signingIn(masked)
                    case .failed(let reason, let detail):
                        failure(reason: reason, detail: detail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.lg)
            }
        }
        .task { await run() }
    }

    // MARK: - Pieces

    private var banner: some View {
        Text("DEBUG BUILD — AUTH GATE BYPASSED")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.sm)
            .background(Theme.warning)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
            .accessibilityIdentifier("debug_bypass_banner")
    }

    private func signingIn(_ masked: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                ProgressView().tint(Theme.accent)
                Text("Signing in as \(masked.isEmpty ? "…" : masked)")
                    .font(Theme.Typeface.cardTitle)
                    .foregroundStyle(Theme.label)
            }
            Text("No keychain session was found, so the bypass is signing in from the QA credentials in this process's environment.")
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("debug_bypass_signing_in")
    }

    private func failure(reason: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("AUTH BYPASS FAILED")
                .font(.title2.weight(.heavy))
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)

            Text(reason)
                .font(Theme.Typeface.cardTitle)
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.secondaryLabel)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Text("You are NOT signed in. Every read returns nothing and every write fails on RLS. This screen is the app telling you that, not the app being broken.")
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Theme.Spacing.md) {
                Button("Retry bypass") { Task { await run(force: true) } }
                    .accessibilityIdentifier("debug_bypass_retry")
                Button("Use the real sign-in screen", action: onUseRealSignIn)
                    .accessibilityIdentifier("debug_bypass_use_real_sign_in")
            }
            .font(Theme.Typeface.cardMeta)
            .buttonStyle(.bordered)
            .tint(Theme.accent)
        }
        .accessibilityIdentifier("debug_bypass_failed")
    }

    // MARK: - The bypass itself

    private func run(force: Bool = false) async {
        if case .failed = status, !force { return }
        DebugAuthBypass.hasAttemptedThisLaunch = true

        guard let creds = DebugAuthBypass.credentials() else {
            fail(reason: "No QA credentials reached the app process.",
                 detail: """
                 The app reads QA_EMAIL and QA_PASSWORD from its OWN environment. \
                 Neither arrived.

                 Under XCUITest they are set on app.launchEnvironment from the \
                 runner's QA_EMAIL / QA_PASSWORD, which xcodebuild only forwards \
                 from host variables carrying the TEST_RUNNER_ prefix.

                 Launching by hand, use the SIMCTL_CHILD_ prefix:
                   source .env.local
                   SIMCTL_CHILD_QA_EMAIL="$DEVTOOLS_TEST_EMAIL" \\
                   SIMCTL_CHILD_QA_PASSWORD="$DEVTOOLS_TEST_PASSWORD" \\
                   xcrun simctl launch --console <udid> com.injectbuddy.ios

                 Wrong prefix = variable silently never arrives.
                 """)
            return
        }

        let masked = DebugAuthBypass.masked(creds.email)
        status = .signingIn(masked)
        DebugAuthBypass.log("no keychain session; signing in as \(masked)")

        await auth.signIn(email: creds.email, password: creds.password)

        // `phase` is driven by the authStateChanges stream, not by signIn's return,
        // so it can lag the call by a tick. Poll rather than assume — and put a
        // ceiling on it so a hang becomes the loud path instead of a spinner.
        let deadline = Date().addingTimeInterval(10)
        while auth.phase != .signedIn, auth.lastError == nil, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if auth.phase == .signedIn {
            DebugAuthBypass.log("signed in as \(masked) — gate bypassed")
            return
        }

        fail(reason: "Sign-in was rejected for \(masked).",
             detail: auth.lastError
                 ?? "No error was reported and no session appeared within 10s. Check the network, the Supabase host in Config/Secrets.xcconfig, and that the QA account still exists.")
    }

    private func fail(reason: String, detail: String) {
        DebugAuthBypass.log("FAILED — \(reason) \(detail.replacingOccurrences(of: "\n", with: " "))")
        status = .failed(reason: reason, detail: detail)
    }
}

#endif
