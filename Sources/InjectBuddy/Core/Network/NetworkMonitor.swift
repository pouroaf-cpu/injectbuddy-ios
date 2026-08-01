import Foundation
import Network

// ─── NetworkMonitor ──────────────────────────────────────────────────────────
// Single, app-wide connectivity source of truth, injected once as an
// @EnvironmentObject (see InjectBuddyApp) so any screen can read `isOnline`
// instead of standing up its own NWPathMonitor. Wraps NWPathMonitor, which starts
// on init on a background queue and calls its handler on THAT queue for every
// path change — publishing @Published straight from there is the classic
// "Publishing changes from background threads is not allowed" purple warning
// (and can misbehave/crash SwiftUI), so every update explicitly hops to the
// main actor before touching state.

final class NetworkMonitor: ObservableObject {
    /// True once the path monitor has reported a satisfied route. Starts optimistic
    /// (`true`) so the very first frame — before NWPathMonitor's first callback
    /// fires — doesn't flash an offline banner while we're actually online.
    @Published private(set) var isOnline: Bool = true
    /// Cellular / personal-hotspot style paths — surfaced for screens that may want
    /// to defer large syncs, not currently gating anything.
    @Published private(set) var isExpensive: Bool = false
    /// Low Data Mode / constrained paths.
    @Published private(set) var isConstrained: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.injectbuddy.networkmonitor")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.apply(path)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    @MainActor
    private func apply(_ path: NWPath) {
        isOnline = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
    }
}
