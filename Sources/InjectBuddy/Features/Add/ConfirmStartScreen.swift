import SwiftUI

// ─── ConfirmStartScreen ──────────────────────────────────────────────────────
// Last step of the Add funnel, mirroring the web's /account/add/confirm/
// (components/account/add/ConfirmStart.tsx).
//
// It closes a real gap, not just a parity one. DoseProjection places a protocol on the
// calendar by counting forward from `start_date`. CalculatorViewModel.save does write
// that column — but hardcoded to TODAY, silently. Anyone adding a protocol they began
// three weeks ago gets every projected occurrence shifted by three weeks, with nothing
// on screen to say so. The calculator cannot know the answer; only the person can.
//
// The row is read back from the database rather than passed in, so what is shown is
// what actually landed, and a row deleted between saving and confirming resolves to a
// clear "no longer available" instead of a screen full of stale values.

struct ConfirmStartScreen: View {
    let dosageId: String

    @EnvironmentObject private var navigator: ShellNavigator
    @EnvironmentObject private var network: NetworkMonitor
    @Environment(\.backend) private var backend
    @StateObject private var vm = ConfirmStartViewModel()

    var body: some View {
        Form {
            switch vm.state {
            case .loading:
                Section { HStack { ProgressView(); Text("Loading…").foregroundStyle(.secondary) } }

            case .missing:
                Section {
                    Text("That protocol is no longer available.")
                        .foregroundStyle(.secondary)
                    Button("Back to dashboard") { navigator.goToDashboard() }
                }

            case .failed(let message):
                Section {
                    Label(network.isOnline ? "Couldn't load that protocol" : "You're offline",
                          systemImage: network.isOnline ? "exclamationmark.triangle" : "wifi.slash")
                        .font(.body.weight(.semibold))
                    Text(network.isOnline
                         ? message
                         : "Your protocol was saved — only the start day is missing. Set it later from the dashboard.")
                        .foregroundStyle(.secondary)
                    Button("Retry") { Task { await vm.load(id: dosageId, backend: backend) } }
                    Button("Back to dashboard") { navigator.goToDashboard() }
                        .foregroundStyle(.secondary)
                }

            case .loaded(let dosage):
                Section("Added to your protocols") {
                    if let label = dosage.label, !label.isEmpty {
                        Text(label).font(.body.weight(.semibold))
                    } else {
                        Text(dosage.calculatorType).font(.body.weight(.semibold))
                    }
                    ForEach(vm.summaryRows, id: \.label) { row in
                        HStack {
                            Text(row.label).foregroundStyle(.secondary)
                            Spacer()
                            Text(row.value).fontWeight(.semibold).monospacedDigit()
                        }
                        .font(.callout)
                    }
                }

                Section {
                    DatePicker("Start day", selection: $vm.startDay, displayedComponents: .date)
                } footer: {
                    Text("Confirm the day this protocol begins so the calendar and dose reminders line up.")
                }

                Section {
                    Button {
                        Task {
                            if await vm.confirm(id: dosageId, backend: backend) { navigator.goToDashboard() }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(vm.isSaving ? "Saving…" : "Confirm start day").fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(vm.isSaving || !network.isOnline)

                    // The protocol is already saved, so leaving costs only the start
                    // day. Without this the only way out is the swipe-back gesture.
                    Button("Set this later") { navigator.goToDashboard() }
                        .foregroundStyle(.secondary)
                } footer: {
                    // The protocol row itself already exists — only the start_date
                    // write needs the network, and "Set this later" is the documented
                    // way out, so offline is a deferral here rather than a dead end.
                    if !network.isOnline {
                        Text("You're offline — confirming the start day needs a connection. Your protocol is already saved; set the day later from the dashboard.")
                    }
                }

                if let error = vm.errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.callout) }
                }
            }
        }
        .task { await vm.load(id: dosageId, backend: backend) }
    }
}

// MARK: - View model

@MainActor
final class ConfirmStartViewModel: ObservableObject {
    enum State {
        case loading
        case missing              // the row genuinely isn't there (deleted between save and confirm)
        case failed(String)       // the load itself failed — says nothing about whether the row exists
        case loaded(SavedDosage)
    }

    struct SummaryRow { let label: String; let value: String }

    @Published var state: State = .loading
    @Published var startDay = Date()
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var summaryRows: [SummaryRow] = []

    // The backend is passed in per call rather than held, matching DashboardViewModel:
    // it lives in the SwiftUI environment so previews and tests can swap in the mock.

    func load(id: String, backend: BackendClient) async {
        do {
            guard let dosage = try await backend.savedDosage(id: id) else {
                state = .missing
                return
            }
            // Respect an existing start_date (re-confirming), else default to today.
            if let existing = dosage.startDate, let parsed = dpParseLocalDay(existing) {
                startDay = parsed
            }
            summaryRows = Self.rows(from: dosage.config)
            state = .loaded(dosage)
        } catch {
            // NOT .missing — a transport failure tells us nothing about whether the
            // row exists, and the user saved it seconds ago. Claiming it's gone is a
            // false statement about their data that invites them to re-create it.
            //
            // And a CANCELLED load is not even a transport failure: this `.task` is torn
            // down when the confirm step is navigated away from, so the error state would
            // be written into a screen on its way out and be waiting on the way back in.
            // Same three lines as the other load paths — see LoadFailure.
            if let message = LoadFailure.message(error) { state = .failed(message) }
        }
    }

    /// Returns true when the write landed, so the caller can navigate away.
    func confirm(id: String, backend: BackendClient) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        do {
            try await backend.updateStartDate(id: id, startDate: dpLocalDay(startDay))
            isSaving = false
            return true
        } catch {
            isSaving = false
            errorMessage = "Could not save the start day. Please try again."
            return false
        }
    }

    // `start_date` is a bare calendar day. This screen used to hold its own private
    // `DateFormatter` for it — correct in frame (local, fixed-format, en_US_POSIX),
    // but the fourth such copy in the app, and the web proved on 2026-08-04 what a
    // pile of private copies costs: two of ITS six reached for `toISOString` and
    // shifted a real user's `start_date` and `measured_on` by a day. It now reads
    // through `dpParseLocalDay` and writes through `dpLocalDay` — the named pair,
    // read and write from the same frame by construction (T-82).

    /// Rendered generically from config rather than per calculator: there are 19 savable
    /// shapes on the web, and a switch over them is a second thing to update every time
    /// one changes — and shows nothing at all for one nobody remembered to add.
    private static func rows(from config: JSONValue) -> [SummaryRow] {
        guard case .object(let dict) = config else { return [] }
        let scalars: [SummaryRow] = dict.keys.sorted().compactMap { key in
            guard let value = dict[key], let text = scalarText(value) else { return nil }
            return SummaryRow(label: humanise(key), value: text)
        }
        return Array(scalars.prefix(8))
    }

    /// Only scalars are worth showing; nested objects and arrays are internal plumbing.
    /// Whole numbers print without a trailing ".0" — config stores everything as a
    /// Double, so 250 would otherwise render as "250.0".
    private static func scalarText(_ value: JSONValue) -> String? {
        switch value {
        case .string(let s): return s.isEmpty ? nil : s
        case .bool(let b):   return b ? "Yes" : "No"
        case .number(let n):
            if n.rounded() == n, abs(n) < 1e15 { return String(Int(n)) }
            return String(format: "%g", n)
        case .object, .array, .null:
            return nil
        }
    }

    /// config keys are terse and internal ("mgWeek"). Split camelCase, sentence-case it.
    private static func humanise(_ key: String) -> String {
        var out = ""
        for ch in key {
            if ch.isUppercase, !out.isEmpty { out.append(" ") }
            out.append(ch)
        }
        out = out.replacingOccurrences(of: "_", with: " ")
        return out.prefix(1).uppercased() + out.dropFirst()
    }
}
