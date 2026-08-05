import SwiftUI

@main
struct InjectBuddyApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var settings = SettingsStore()
    /// Created once here — never per-screen — and read via @EnvironmentObject.
    @StateObject private var network = NetworkMonitor()

    /// The live backend. Swap for a mock in previews/tests via the environment key.
    private let backend: BackendClient = SupabaseBackendClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(settings)
                .environmentObject(network)
                .environment(\.backend, backend)
                .tint(Theme.accent)
                // Belt-and-braces alongside UIUserInterfaceStyle=Light in
                // project.yml. The plist key is the real lock — it also covers
                // keyboards, sheets and the launch screen, which this cannot reach.
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    // Discord OAuth callback + email-confirmation deep links.
                    auth.handleOAuthCallback(url: url)
                }
        }
    }
}

// MARK: - Backend in the environment

private struct BackendKey: EnvironmentKey {
    static let defaultValue: BackendClient = SupabaseBackendClient()
}

extension EnvironmentValues {
    var backend: BackendClient {
        get { self[BackendKey.self] }
        set { self[BackendKey.self] = newValue }
    }
}
