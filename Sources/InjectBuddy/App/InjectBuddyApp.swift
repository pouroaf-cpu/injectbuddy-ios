import SwiftUI

@main
struct InjectBuddyApp: App {
    @StateObject private var auth = AuthStore()
    @StateObject private var settings = SettingsStore()

    /// The live backend. Swap for a mock in previews/tests via the environment key.
    private let backend: BackendClient = SupabaseBackendClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(settings)
                .environment(\.backend, backend)
                .tint(Theme.accent)
                .preferredColorScheme(settings.theme.colorScheme)
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
