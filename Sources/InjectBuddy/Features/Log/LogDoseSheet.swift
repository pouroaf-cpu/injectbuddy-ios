import SwiftUI

// ─── LogDoseSheet ────────────────────────────────────────────────────────────
// What the raised centre hero opens. The web equivalent is DashLogFlow, reached from
// the same slot via the ib:log-dose bridge.
//
// Deliberately the LEAN version (operator, 2026-07-30): pick a protocol, log it for a
// day. No body-site picker — `site` stays nil, and site rotation is a dashboard feature
// that belongs with that rewrite, not in this sheet.
//
// `draw_ml` is NO LONGER left nil, and the note that used to stand here — "no draw
// volume … exactly as DashboardViewModel.markTaken already does" — was describing the
// defect rather than a decision. There is no volume PICKER, which is what "lean" meant;
// there is a volume, derived from the chosen protocol's own config by
// `DoseVolume.perInjectionMl`. Nothing is asked of the user for it.
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

    /// One protocol, compound-first, in the calculator's field language.
    @ViewBuilder
    private func protocolRow(_ p: SavedDosage) -> some View {
        let raw = p.label?.isEmpty == false ? p.label! : p.calculatorType
        let parts = ProtocolLabel.split(raw)
        let isSelected = selectedId == p.id
        Button {
            selectedId = p.id
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(parts.compound)
                        .font(Theme.Typeface.cardTitle)
                        .foregroundStyle(Theme.inkNavy)
                        .fixedSize(horizontal: false, vertical: true)
                    if !parts.dose.isEmpty {
                        Text(parts.dose)
                            .font(Theme.Typeface.cardMeta)
                            .foregroundStyle(Theme.secondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: Theme.Spacing.sm)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.tealTextStrong)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .fieldChrome(isFocused: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

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
                    Section {
                        // Was an inline Picker of single-line rows rendering the raw
                        // dose-first label — "85mg/wk · Testosterone Enanthate" — in
                        // stock 17pt regular. That is the exact pattern that made
                        // seven dashboard cards truncate their compound and two render
                        // identically; it had simply not been triggered here yet.
                        //
                        // Replaced with explicit rows so the compound leads, nothing
                        // carries a lineLimit, and the calculator's bordered field
                        // language applies. Selection is drawn rather than delegated
                        // to Picker, which is what allows the row treatment at all.
                        ForEach(protocols) { p in
                            protocolRow(p)
                        }
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } header: {
                        // Navy semibold, like every other section eyebrow in the app.
                        // Stock Form headers render grey #85858B at 3.29:1.
                        Text("Which protocol?".uppercased())
                            .font(Theme.Typeface.eyebrow)
                            .foregroundStyle(Theme.navy)
                            .textCase(nil)
                    }

                    Section {
                        // The compact DatePicker's chip measured 34.3pt — under the
                        // 44pt floor, on the control that sets WHICH DAY a dose was
                        // administered. Floored at 44 and given the calculator's
                        // field treatment (r10 / 1pt #8E8E93 / white) so it stops
                        // reading as a stock grey chip on an otherwise branded app.
                        DatePicker("Day", selection: $day, displayedComponents: .date)
                            .frame(minHeight: Theme.minTarget)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .fieldChrome()
                            .listRowInsets(EdgeInsets(top: Theme.Spacing.sm,
                                                      leading: Theme.Spacing.md,
                                                      bottom: Theme.Spacing.sm,
                                                      trailing: Theme.Spacing.md))
                    }

                    if !network.isOnline {
                        Section {
                            Text("You're offline — logging a dose needs a connection.")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryLabel)
                        }
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.callout) }
                }
            }
            // The CTA lives OUTSIDE the List. Inside it, in a row with
            // `.listRowInsets(EdgeInsets())`, the row constrained it and it measured
            // 71.7pt at AX5 against the calculator's 91.3pt — the same component
            // rendering two sizes, and the log sheet's simply not scaling with
            // Dynamic Type. A CTA sized for default text at AX5 is not acceptable.
            .safeAreaInset(edge: .bottom) {
                if !isLoading && !protocols.isEmpty {
                    PrimaryButton(
                        title: "Log dose",
                        isLoading: isSaving,
                        isEnabled: selectedId != nil && network.isOnline
                    ) {
                        Task { await log() }
                    }
                    .padding(Theme.Spacing.md)
                    .background(.bar)
                }
            }
            .navigationTitle("Log a dose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // The app-wide `.tint(Theme.accent)` made this #0FBCAD on
                    // #F2F2F7 — 2.13:1, the worst number left in the app and the
                    // same teal-as-text pairing removed everywhere else.
                    Button("Cancel") { dismiss() }
                        .tint(Theme.tealTextStrong)
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
        // The PROTOCOL, not just its id: the draw volume is derived from its config.
        guard let id = selectedId,
              let dosage = protocols.first(where: { $0.id == id }),
              !isSaving else { return }
        isSaving = true
        errorMessage = nil
        let pin = NewDoseLogPin(for: dosage,
                                dosedOn: Self.dayFormatter.string(from: day))
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
