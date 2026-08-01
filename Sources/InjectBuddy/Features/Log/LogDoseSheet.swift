import SwiftUI

// ─── LogDoseSheet ────────────────────────────────────────────────────────────
// What the raised centre hero opens. The web equivalent is DashLogFlow, reached from
// the same slot via the ib:log-dose bridge.
//
// Deliberately the LEAN version (operator, 2026-07-30): pick a protocol, log it for a
// day. No body-site picker, no draw volume — both columns exist on dose_log and both
// are left nil here, exactly as DashboardViewModel.markTaken already does. Site
// rotation is a dashboard feature and belongs with that rewrite, not in this sheet.
//
// It writes through the same backend.logDose the dashboard uses, so there is one
// dose-write path in the app rather than a second one drifting alongside it.

struct LogDoseSheet: View {
    @EnvironmentObject private var navigator: ShellNavigator
    @EnvironmentObject private var network: NetworkMonitor
    @Environment(\.backend) private var backend
    @Environment(\.dismiss) private var dismiss

    @State private var protocols: [SavedDosage] = []
    @State private var selectedId: String?
    @State private var day = Date()
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    Section { HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) } }
                } else if protocols.isEmpty && !network.isOnline {
                    // The load failed because there's no connection — NOT because the
                    // user has no protocols. Saying "No protocols yet" here would be a
                    // lie that pushes them into creating a duplicate.
                    Section {
                        Label("You're offline", systemImage: "wifi.slash")
                            .font(.body.weight(.semibold))
                        Text("Your protocols couldn't be loaded. Reconnect to log a dose.")
                            .foregroundStyle(.secondary)
                        Button("Retry") { Task { await load() } }
                    }
                } else if protocols.isEmpty {
                    Section {
                        Text("No protocols yet.")
                            .foregroundStyle(.secondary)
                        Button("Add one") {
                            dismiss()
                            navigator.selectTab(.add)
                        }
                    }
                } else {
                    Section("Which protocol?") {
                        Picker("Protocol", selection: $selectedId) {
                            ForEach(protocols) { p in
                                Text(p.label?.isEmpty == false ? p.label! : p.calculatorType)
                                    .tag(Optional(p.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.inline)
                    }

                    Section {
                        DatePicker("Day", selection: $day, displayedComponents: .date)
                    }

                    Section {
                        Button {
                            Task { await log() }
                        } label: {
                            HStack {
                                Spacer()
                                Text(isSaving ? "Logging…" : "Log dose").fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(isSaving || selectedId == nil || !network.isOnline)
                    } footer: {
                        if !network.isOnline {
                            Text("You're offline — logging a dose needs a connection.")
                        }
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.callout) }
                }
            }
            .navigationTitle("Log a dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        do {
            let rows = try await backend.savedDosages()
            protocols = rows.filter(\.isActive)
            selectedId = protocols.first?.id
        } catch {
            errorMessage = "Could not load your protocols."
        }
        isLoading = false
    }

    private func log() async {
        guard let id = selectedId, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        let pin = NewDoseLogPin(protocolId: id,
                                dosedOn: Self.dayFormatter.string(from: day),
                                drawMl: nil, site: nil)
        do {
            _ = try await backend.logDose(pin)
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            errorMessage = "Could not log that dose. Please try again."
        }
    }

    /// `dose_log.dosed_on` is a bare calendar day. Fixed-format and en_US_POSIX so it
    /// is never localised into a shape the column rejects — same contract as
    /// DoseProjection's day keys.
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
