import SwiftUI

// ─── DashboardScreen ─────────────────────────────────────────────────────────
// The app's default screen (cycle planner). Greeting → NEXT DOSE → THIS CYCLE
// timeline → PROTOCOLS grid (+ Add) → WEEK AT A GLANCE. Loads through
// DashboardViewModel and renders loading / empty / error / loaded off its LoadState.

struct DashboardScreen: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var navigator: ShellNavigator
    @Environment(\.backend) private var backend

    @StateObject private var vm = DashboardViewModel()
    @State private var showCalculatorPicker = false

    init() {}

    var body: some View {
        content
            .background(Theme.groupedBackground.ignoresSafeArea())
            .task { await reload() }
            .refreshable { await reload() }
            .confirmationDialog("Add a protocol", isPresented: $showCalculatorPicker, titleVisibility: .visible) {
                ForEach(CalculatorSlug.allCases) { slug in
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
            ErrorBanner(message: message) { Task { await reload() } }
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
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                greeting

                if let next = data.nextDose {
                    NextDoseCard(model: next, now: Date()) {
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
                            .font(.subheadline.weight(.medium))
                    }
                    .tint(Theme.accent)
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
        }
    }

    private var greeting: some View {
        Text("\(Self.greetingPrefix(for: Date())), \(auth.identity?.displayName ?? "there")")
            .font(.title2.weight(.bold))
            .foregroundStyle(Theme.label)
    }

    // MARK: section header helper

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryLabel)
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryLabel)
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
}

#Preview("Empty") {
    DashboardScreen()
        .environment(\.backend, MockBackendClient(dosages: [], cycles: []))
        .environmentObject(AuthStore())
        .environmentObject(SettingsStore())
        .environmentObject(ShellNavigator())
}
#endif
