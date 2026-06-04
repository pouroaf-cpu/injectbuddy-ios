import SwiftUI

// ─── AuthFlowView ────────────────────────────────────────────────────────────
// Pre-auth screen (no drawer). Login / Sign up / Reset, Supabase email + Discord
// OAuth. On success AuthStore flips to .signedIn and RootView swaps in MainShell.

struct AuthFlowView: View {
    enum Mode { case login, signUp, reset }

    @EnvironmentObject private var auth: AuthStore
    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var isSubmitting = false
    @State private var resetSent = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer(minLength: Theme.Spacing.xl)
                BrandMark().font(.largeTitle)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)

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
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if resetSent {
                    Text("If that email exists, a reset link is on its way.")
                        .font(.footnote)
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

                footerLinks
                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Derived

    private var subtitle: String {
        switch mode {
        case .login: return "Sign in to your protocols"
        case .signUp: return "Create your account"
        case .reset: return "Reset your password"
        }
    }
    private var primaryTitle: String {
        switch mode {
        case .login: return "Sign in"
        case .signUp: return "Sign up"
        case .reset: return "Send reset link"
        }
    }
    private var isValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        switch mode {
        case .login: return emailOK && password.count >= 6
        case .signUp: return emailOK && password.count >= 6 && password == confirm
        case .reset: return emailOK
        }
    }

    @ViewBuilder private var footerLinks: some View {
        switch mode {
        case .login:
            HStack {
                Button("Forgot password?") { switchTo(.reset) }
                Spacer()
                Button("Create account") { switchTo(.signUp) }
            }
            .font(.footnote)
        case .signUp:
            Button("Already have an account? Sign in") { switchTo(.login) }
                .font(.footnote)
        case .reset:
            Button("‹ Back to sign in") { switchTo(.login) }
                .font(.footnote)
        }
    }

    // MARK: - Actions

    private func switchTo(_ new: Mode) {
        auth.lastError = nil
        resetSent = false
        withAnimation(.easeInOut(duration: 0.2)) { mode = new }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        switch mode {
        case .login:
            await auth.signIn(email: email, password: password)
        case .signUp:
            await auth.signUp(email: email, password: password)
        case .reset:
            await auth.sendPasswordReset(email: email)
            if auth.lastError == nil { resetSent = true }
        }
    }
}
