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
            // a persisted login and reacts to later sign-in/out.
            guard let stream = self?.client.auth.authStateChanges else { return }
            for await change in stream {
                await self?.apply(session: change.session)
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

    func signUp(email: String, password: String) async {
        lastError = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            // If email confirmation is required, signUp returns no session; surface it.
            if (try? await client.auth.session) == nil {
                lastError = "Check your email to confirm your account, then sign in."
            }
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
            // supabase-swift drives an ASWebAuthenticationSession for OAuth on iOS.
            try await client.auth.signInWithOAuth(provider: .discord)
        } catch {
            lastError = Self.message(error)
        }
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
}
