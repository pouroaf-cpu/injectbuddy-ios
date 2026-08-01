import SwiftUI

// ─── AuthFlowView ────────────────────────────────────────────────────────────
// Pre-auth screen (no drawer). Login / Sign up / Reset / Verify, Supabase email +
// Discord OAuth. On success AuthStore flips to .signedIn and RootView swaps in
// MainShell. Signing up with confirmations enabled doesn't produce a session, so
// submit() routes into .verify instead — the "check your email" holding screen.

struct AuthFlowView: View {
    enum Mode { case login, signUp, reset, verify }

    /// Which form to open on — the welcome screen's two CTAs land on different ones.
    var initialMode: Mode = .login

    @EnvironmentObject private var auth: AuthStore
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var isSubmitting = false
    @State private var resetSent = false

    // Verify-mode only: resend has its own in-flight flag (distinct from isSubmitting,
    // which belongs to the form's PrimaryButton) plus a cooldown so a user can't hammer
    // the resend endpoint. cooldownTask drives the per-second countdown.
    @State private var isResending = false
    @State private var resendCooldown = 0
    @State private var resendConfirmed = false
    @State private var cooldownTask: Task<Void, Never>?
    private static let resendCooldownSeconds = 30

    var body: some View {
        content.onAppear { mode = initialMode }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: Theme.Spacing.xl)
                BrandMark().font(.largeTitle)
                Text(subtitle)
                    .font(Theme.Typeface.cardMeta)
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                if mode == .verify {
                    verifyContent
                } else {
                    VStack(spacing: Theme.Spacing.md) {
                        AuthField(systemImage: "envelope", placeholder: "Email", text: $email,
                                  keyboard: .emailAddress, isSecure: false)

                        if mode != .reset {
                            AuthField(systemImage: "lock", placeholder: "Password", text: $password,
                                      isSecure: true)
                        }
                        if mode == .signUp {
                            AuthField(systemImage: "lock.rotation", placeholder: "Confirm password",
                                      text: $confirm, isSecure: true)
                        }
                    }

                    if let error = auth.lastError {
                        Text(error)
                            .font(Theme.Typeface.cardMeta)
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if resetSent {
                        Text("If that email exists, a reset link is on its way.")
                            .font(Theme.Typeface.cardMeta)
                            .foregroundStyle(Theme.success)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: primaryTitle, isLoading: isSubmitting, isEnabled: isValid) {
                        Task { await submit() }
                    }

                    if mode != .reset {
                        LabeledDivider(text: "or")
                        OAuthButton(title: "Continue with Discord", systemImage: "bubble.left.and.bubble.right.fill") {
                            Task { isSubmitting = true; await auth.signInWithDiscord(); isSubmitting = false }
                        }
                    }
                }

                footerLinks
                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.canvas.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .onDisappear { cooldownTask?.cancel() }
    }

    // MARK: - Verify

    @ViewBuilder private var verifyContent: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text("We sent a confirmation link to")
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            Text(email)
                .font(Theme.Typeface.cardTitle)
                .foregroundStyle(Theme.inkNavy)
                .fixedSize(horizontal: false, vertical: true)
            Text("Open it on this device to activate your account, then come back here and sign in.")
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.secondaryLabel)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)

        if let error = auth.lastError {
            Text(error)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if resendConfirmed {
            Text("Confirmation email resent.")
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.success)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        PrimaryButton(title: resendTitle, isLoading: isResending, isEnabled: resendCooldown == 0) {
            Task { await resendVerificationEmail() }
        }
    }

    private var resendTitle: String {
        resendCooldown > 0 ? "Resend in \(resendCooldown)s" : "Resend email"
    }

    // MARK: - Derived

    private var subtitle: String {
        switch mode {
        case .login: return "Sign in to your protocols"
        case .signUp: return "Create your account"
        case .reset: return "Reset your password"
        case .verify: return "Confirm your account"
        }
    }
    private var primaryTitle: String {
        switch mode {
        case .login: return "Sign in"
        case .signUp: return "Sign up"
        case .reset: return "Send reset link"
        case .verify: return "Resend email" // unused: verifyContent renders its own button
        }
    }
    private var isValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        switch mode {
        case .login: return emailOK && password.count >= 6
        case .signUp: return emailOK && password.count >= 6 && password == confirm
        case .reset: return emailOK
        case .verify: return false // no form to submit in this mode
        }
    }

    @ViewBuilder private var footerLinks: some View {
        switch mode {
        case .login:
            HStack {
                Button("Forgot password?") { switchTo(.reset) }
                    .tint(Theme.tealTextStrong)
                Spacer()
                Button("Create account") { switchTo(.signUp) }
                    .tint(Theme.tealTextStrong)
            }
            .font(Theme.Typeface.cardMeta)
        case .signUp:
            Button("Already have an account? Sign in") { switchTo(.login) }
                .font(Theme.Typeface.cardMeta)
                .tint(Theme.tealTextStrong)
        case .reset, .verify:
            Button("‹ Back to sign in") { switchTo(.login) }
                .tint(Theme.tealTextStrong)
                .font(Theme.Typeface.cardMeta)
        }
    }

    // MARK: - Actions

    private func switchTo(_ new: Mode) {
        auth.lastError = nil
        resetSent = false
        cooldownTask?.cancel()
        resendCooldown = 0
        resendConfirmed = false
        withAnimation(.easeInOut(duration: 0.2)) { mode = new }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        switch mode {
        case .login:
            await auth.signIn(email: email, password: password)
        case .signUp:
            let needsConfirmation = await auth.signUp(email: email, password: password)
            if needsConfirmation { switchTo(.verify) }
        case .reset:
            await auth.sendPasswordReset(email: email)
            if auth.lastError == nil { resetSent = true }
        case .verify:
            break // handled by resendVerificationEmail(), not the form's submit button
        }
    }

    private func resendVerificationEmail() async {
        guard resendCooldown == 0 else { return }
        isResending = true
        resendConfirmed = false
        await auth.resendConfirmationEmail(email)
        isResending = false
        guard auth.lastError == nil else { return }
        resendConfirmed = true
        startResendCooldown()
    }

    private func startResendCooldown() {
        resendCooldown = Self.resendCooldownSeconds
        cooldownTask?.cancel()
        cooldownTask = Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                resendCooldown -= 1
            }
        }
    }
}
