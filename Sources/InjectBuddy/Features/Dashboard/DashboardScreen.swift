import SwiftUI

// ─── DashboardScreen ─────────────────────────────────────────────────────────
// The app's default screen (cycle planner). Greeting → NEXT DOSE → THIS CYCLE
// timeline → PROTOCOLS grid (+ Add) → WEEK AT A GLANCE. Loads through
// DashboardViewModel and renders loading / empty / error / loaded off its LoadState.

struct DashboardScreen: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var navigator: ShellNavigator
    @EnvironmentObject private var network: NetworkMonitor
    @Environment(\.backend) private var backend

    @StateObject private var vm = DashboardViewModel()
    @State private var showCalculatorPicker = false

    init() {}

    var body: some View {
        content
            .background(Theme.canvas.ignoresSafeArea())
            .task { await reload() }
            .refreshable { await reload() }
            .confirmationDialog("Add a protocol", isPresented: $showCalculatorPicker, titleVisibility: .visible) {
                // `listedCases`, not `allCases` — H6 withdraws BMI and Free T Index from
                // every route in, and this dialog is one. It still offers Cycle Plotter,
                // which cannot save either: that is deliberate, it is the plotter's only
                // route into the app today and it stays reachable.
                ForEach(CalculatorSlug.listedCases) { slug in
                    Button(slug.title) { navigator.push(.calculator(slug)) }
                }
                Button("Cancel", role: .cancel) {}
            }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            // A failed load with nothing cached, while offline, is the "nothing
            // to show" case the design's offline screen covers — a generic
            // server-error banner would be misleading here.
            if network.isOnline {
                ErrorBanner(message: message) { Task { await reload() } }
            } else {
                OfflineView { Task { await reload() } }
            }
        case .empty:
            EmptyStateView(
                systemImage: "syringe",
                title: "No protocols yet",
                message: "Add your first protocol to start planning your cycle.",
                actionTitle: "Add your first protocol",
                action: { showCalculatorPicker = true }
            )
        case .loaded(let data):
            loaded(data)
        }
    }

    private func loaded(_ data: DashboardData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                greeting

                // A dose that did not get logged says so HERE, on the screen the user
                // pressed the button on. `vm.state` is the load channel and stays the
                // load channel: routing a write failure through it would blank the
                // dashboard, and the old code routed it nowhere at all.
                if let actionError = vm.actionError {
                    InlineErrorNote(message: actionError) { vm.actionError = nil }
                }

                if let next = data.nextDose {
                    NextDoseCard(model: next, now: Date(), isMarking: vm.isMarkingTaken) {
                        Task { await vm.markTaken(next.occurrence, backend: backend) }
                    }
                }

                if let cycle = data.cycle {
                    section("This cycle") {
                        CycleTimelineStrip(progress: cycle, occurrences: data.upcoming, now: Date())
                    }
                }

                section("Protocols", trailing: {
                    Button { showCalculatorPicker = true } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(minHeight: Theme.minTarget)
                            .contentShape(Rectangle())
                    }
                    .tint(Theme.tealTextStrong)
                    // Addressed by IDENTIFIER, not by the label. `Add` is also the tab
                    // bar's middle slot, and a check that resolved this control by its
                    // text spent a week measuring the tab bar instead — always enabled,
                    // always hittable, on exactly the screens where the real control was
                    // not (§5.38). Names the control, adds no element to the tree (§5.39).
                    .accessibilityIdentifier("cta_add_protocol")
                }) {
                    ProtocolGrid(protocols: data.protocols) { proto in
                        if let slug = proto.slug {
                            navigator.push(.calculator(slug))
                        }
                    }
                }

                if !data.weeklyTotals.isEmpty {
                    section("Week at a glance") {
                        StatsIsland(totals: data.weeklyTotals)
                    }
                }
            }
            .padding(Theme.Spacing.md)
            // No hero/tab-bar padding here any more: MainShell reserves it as a
            // bottom safe-area inset for every tab, so doing it again would
            // double-count.
        }
    }

    private var greeting: some View {
        GreetingHeadline(
            prefix: Self.greetingPrefix(for: Date()),
            name: Self.firstName(auth.identity?.displayName)
        )
    }

    /// The PWA greets by first name only — `DashHeader.tsx` does `.split(/\s+/)[0]`.
    /// "Pouroa frew" becomes "Pou." there because the PWA also truncates; we keep
    /// the whole first name rather than copying a truncation.
    static func firstName(_ displayName: String?) -> String {
        guard let raw = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return "there" }
        return raw.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? raw
    }

    // MARK: section header helper

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title.uppercased())
                .font(Theme.Typeface.eyebrow)
                .foregroundStyle(Theme.navy)
            content()
        }
    }

    @ViewBuilder
    private func section<Trailing: View, Content: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(title.uppercased())
                    .font(Theme.Typeface.eyebrow)
                    .foregroundStyle(Theme.navy)
                Spacer()
                trailing()
            }
            content()
        }
    }

    private func reload() async {
        await vm.load(backend: backend, userId: auth.currentUserId)
    }

    static func greetingPrefix(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }
}

#if DEBUG
#Preview("Loaded") {
    DashboardScreen()
        .environment(\.backend, MockBackendClient())
        .environmentObject(AuthStore())
        .environmentObject(SettingsStore())
        .environmentObject(ShellNavigator())
        .environmentObject(NetworkMonitor())
}

#Preview("Empty") {
    DashboardScreen()
        .environment(\.backend, MockBackendClient(dosages: [], cycles: []))
        .environmentObject(AuthStore())
        .environmentObject(SettingsStore())
        .environmentObject(ShellNavigator())
        .environmentObject(NetworkMonitor())
}
#endif
