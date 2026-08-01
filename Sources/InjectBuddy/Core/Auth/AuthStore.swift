import Foundation
import Supabase

// ─── AuthStore ───────────────────────────────────────────────────────────────
// Owns the Supabase auth session. RootView switches on `phase`. supabase-swift
// persists the session to the keychain, so a returning user lands straight on the
// dashboard. Built as an ObservableObject (works on iOS 16; @Observable is iOS 17).

@MainActor
final class AuthStore: ObservableObject {

    enum Phase: Equatable {
        case loading        // checking persisted session at launch
        case signedOut
        case signedIn
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var identity: AccountIdentity?
    @Published private(set) var currentUserId: String?
    @Published var lastError: String?

    private var client: SupabaseClient { SupabaseProvider.client }
    private var watchTask: Task<Void, Never>?

    init() {
        watchTask = Task { [weak self] in
            // authStateChanges emits the initial session too, so this both restores
            // a persisted login and reacts to later sign-in/out. Source the stream from
            // the global (not self) to avoid a retain cycle that would block deinit.
            for await (_, session) in await SupabaseProvider.client.auth.authStateChanges {
                await self?.apply(session: session)
            }
        }
    }

    deinit { watchTask?.cancel() }

    private func apply(session: Session?) {
        if let session {
            identity = Self.identity(from: session.user)
            currentUserId = session.user.id.uuidString
            phase = .signedIn
        } else {
            identity = nil
            currentUserId = nil
            phase = .signedOut
        }
    }

    // MARK: - Actions

    func signIn(email: String, password: String) async {
        lastError = nil
        do {
            _ = try await client.auth.signIn(email: email, password: password)
        } catch {
            lastError = Self.message(error)
        }
    }

    /// Returns `true` when Supabase requires email confirmation before a session exists
    /// (the common case with confirmations turned on), so AuthFlowView can route to the
    /// "check your email" screen instead of treating this as a completed sign-in.
    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        lastError = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            return (try? await client.auth.session) == nil
        } catch {
            lastError = Self.message(error)
            return false
        }
    }

    /// Resends the signup confirmation email. Supabase reports success even for an address
    /// that was never registered, so there's no "not found" branch to surface here — only
    /// transport/rate-limit failures land in lastError.
    func resendConfirmationEmail(_ email: String) async {
        lastError = nil
        do {
            try await client.auth.resend(
                email: email,
                type: .signup,
                emailRedirectTo: SupabaseConfig.oauthRedirectURL
            )
        } catch {
            lastError = Self.message(error)
        }
    }

    func sendPasswordReset(email: String) async {
        lastError = nil
        do {
            try await client.auth.resetPasswordForEmail(email)
        } catch {
            lastError = Self.message(error)
        }
    }

    func signInWithDiscord() async {
        lastError = nil
        do {
            // supabase-swift drives an ASWebAuthenticationSession for OAuth on iOS and
            // completes on the registered callback scheme (see SupabaseConfig.oauthRedirectURL
            // + Info.plist CFBundleURLTypes + the Supabase dashboard redirect allow-list).
            try await client.auth.signInWithOAuth(
                provider: .discord,
                redirectTo: SupabaseConfig.oauthRedirectURL
            )
        } catch {
            // User-cancelled web auth surfaces as an error; treat cancel as a no-op.
            if !Self.isUserCancellation(error) { lastError = Self.message(error) }
        }
    }

    /// Deep-link handler for OAuth redirects + email-confirmation links. supabase-swift
    /// parses the URL and updates the session (no-op for unrelated URLs). Wired from
    /// InjectBuddyApp's `.onOpenURL`. `handle` is synchronous and non-throwing.
    func handleOAuthCallback(url: URL) {
        client.auth.handle(url)
    }

    func signOut() async {
        do { try await client.auth.signOut() } catch { lastError = Self.message(error) }
    }

    /// Optimistically reflect a display-name change made in Settings.
    func setDisplayName(_ name: String) {
        guard var id = identity else { return }
        id.displayName = name
        identity = id
    }

    // MARK: - Helpers

    private static func identity(from user: User) -> AccountIdentity {
        let meta = user.userMetadata
        let email = user.email ?? ""
        let name = meta["display_name"]?.stringValue
            ?? meta["full_name"]?.stringValue
            ?? meta["name"]?.stringValue
            ?? (email.split(separator: "@").first.map(String.init) ?? "User")
        let avatar = meta["avatar_url"]?.stringValue.flatMap(URL.init(string:))
        return AccountIdentity(email: email, displayName: name, avatarURL: avatar)
    }

    private static func message(_ error: Error) -> String {
        error.localizedDescription
    }

    /// True when the user dismissed the OAuth web sheet (ASWebAuthenticationSession
    /// canceledLogin) — not a real failure, so we shouldn't show an error.
    private static func isUserCancellation(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == "com.apple.AuthenticationServices.WebAuthenticationSession"
            && ns.code == 1
    }
}
