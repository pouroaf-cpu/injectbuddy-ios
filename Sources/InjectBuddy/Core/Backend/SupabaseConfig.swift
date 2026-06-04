import Foundation
import Supabase

// ─── SupabaseConfig + client provider ────────────────────────────────────────
// Reads SUPABASE_HOST + SUPABASE_ANON_KEY from Info.plist (populated at build time
// from Config/Secrets.xcconfig — never hard-coded). The anon key is RLS-gated and
// safe in a client binary; the service-role key must never ship.

enum SupabaseConfig {
    static let host: String = infoValue("SUPABASE_HOST")
    static let anonKey: String = infoValue("SUPABASE_ANON_KEY")

    /// xcconfig can't store a "//" (it's a comment), so we keep the bare host and
    /// rebuild the https URL here.
    static var url: URL {
        let trimmed = host.hasPrefix("http") ? host : "https://\(host)"
        guard let u = URL(string: trimmed) else {
            fatalError("Invalid SUPABASE_HOST: \(host). Set it in Config/Secrets.xcconfig.")
        }
        return u
    }

    /// OAuth deep-link callback. Must be registered BOTH in Info.plist (CFBundleURLTypes —
    /// scheme `com.injectbuddy.ios`) AND in the Supabase dashboard → Auth → URL Configuration →
    /// Redirect URLs. Used by Discord sign-in.
    static let oauthRedirectURL = URL(string: "com.injectbuddy.ios://login-callback")!

    private static func infoValue(_ key: String) -> String {
        guard let v = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !v.isEmpty, !v.contains("YOUR_") else {
            assertionFailure("Missing \(key). Copy Config/Secrets.example.xcconfig → Secrets.xcconfig and fill it in.")
            return ""
        }
        return v
    }
}

/// Single shared SupabaseClient. supabase-swift persists the auth session to the
/// keychain by default, so sign-in survives app relaunch (TASK 2 "persist in Keychain").
enum SupabaseProvider {
    static let client = SupabaseClient(
        supabaseURL: SupabaseConfig.url,
        supabaseKey: SupabaseConfig.anonKey
    )
}
