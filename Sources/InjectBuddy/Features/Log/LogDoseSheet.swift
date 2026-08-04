import SwiftUI

// ─── LogDoseSheet ────────────────────────────────────────────────────────────
// What the raised centre hero opens. The web equivalent is DashLogFlow, reached from
// the same slot via the ib:log-dose bridge.
//
// It was DELIBERATELY the LEAN version (operator, 2026-07-30): pick a protocol, log it
// for a day, no body-site picker — "`site` stays nil, and site rotation is a dashboard
// feature that belongs with that rewrite". **That decision is reversed** (TASKS T-03).
// It was not a feature being deferred: `dose_log.site` is a column the web fills on
// every row and derives its whole rotation model from — eight IM sites, six SubQ, a
// 3.5-day rest convention and a body map. Leaving it NULL did not postpone a screen iOS
// does not have; it wrote a hole into data the user already owns and reads on the web.
//
// So the sheet now asks for the site, and the SITE PICKER IS THE WHOLE FEATURE HERE —
// the rotation model itself still lives on the web. What this sheet owes it is a label
// from `InjectionSite`'s track, spelled the web's way, and a sensible default: one step
// past the last site logged against this protocol, which is the web's own `nextSiteIdx`.
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

    /// Existing pins, read only to work out which site comes next in the rotation. A
    /// failure to load them is NOT an error the user sees — it costs the suggestion, not
    /// the ability to log a dose, so it degrades to the per-protocol seed.
    @State private var pins: [DoseLogPin] = []

    /// The site the user has chosen, per protocol. Keyed by protocol id rather than held
    /// as one value because switching protocol can switch TRACK — an IM site selected
    /// for a TRT row is not a legal choice for a peptide row, and carrying it across
    /// would offer to write "L Glute" on a subcutaneous dose.
    @State private var chosenSite: [String: String] = [:]

    /// The protocol currently selected, if any.
    private var selectedProtocol: SavedDosage? {
        guard let selectedId else { return nil }
        return protocols.first { $0.id == selectedId }
    }

    /// The site that will be written: what the user picked, else the rotation's
    /// suggestion. nil only when this protocol has no track at all (an oral steroid).
    private var siteForSelection: String? {
        guard let p = selectedProtocol else { return nil }
        if let chosen = chosenSite[p.id] { return chosen }
        return InjectionSite.suggested(for: p, pins: pins, seed: protocols.firstIndex(of: p) ?? 0)
    }

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

    /// One site in the rotation track. Deliberately the SAME row shape as `protocolRow`
    /// — full width, 44pt floor, no `lineLimit` anywhere — rather than a grid of pills.
    /// "R Love handle" in a fixed-width pill is a truncated body part at AX5, and a
    /// sheared site label reads as a different site rather than as a clipped one.
    @ViewBuilder
    private func siteRow(_ site: String, isSelected: Bool, isSuggested: Bool, protocolId: String) -> some View {
        Button {
            chosenSite[protocolId] = site
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Text(site)
                    .font(Theme.Typeface.cardTitle)
                    .foregroundStyle(Theme.inkNavy)
                    .fixedSize(horizontal: false, vertical: true)
                if isSuggested {
                    // Says WHY this one is already ticked. Without it the default looks
                    // arbitrary, and an arbitrary-looking default gets accepted without
                    // being read — which is how a rotation ends up all in one muscle.
                    Text("next in rotation")
                        .font(Theme.Typeface.cardMeta)
                        .foregroundStyle(Theme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
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
        // The site label alone is not a usable query handle: "Log dose" already exists
        // twice in the tree (this sheet's CTA and the tab item behind it), which is the
        // shape of mistake that once photographed the wrong screen. An identifier the
        // round-trip check can name exactly is cheaper than a heuristic.
        .accessibilityIdentifier("logDose.site.\(site)")
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

                    // WHERE the dose went. Only rendered when the selected protocol has
                    // a track: an oral steroid has no injection site, and offering one
                    // would put a body location on a tablet — the web gives that branch
                    // `sites: []` for the same reason.
                    if let p = selectedProtocol,
                       let route = InjectionSite.route(for: p),
                       case let sites = InjectionSite.track(for: p), !sites.isEmpty {
                        let suggested = InjectionSite.suggested(
                            for: p, pins: pins, seed: protocols.firstIndex(of: p) ?? 0)
                        Section {
                            ForEach(sites, id: \.self) { site in
                                siteRow(site,
                                        isSelected: siteForSelection == site,
                                        isSuggested: chosenSite[p.id] == nil && suggested == site,
                                        protocolId: p.id)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        } header: {
                            Text(route.trackTitle.uppercased())
                                .font(Theme.Typeface.eyebrow)
                                .foregroundStyle(Theme.navy)
                                .textCase(nil)
                        }
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
                    // On the button ITSELF, not on the padded bar around it: an
                    // identifier set on a container is not reliably the identifier of
                    // the button inside it, and "Log dose" alone is ambiguous — the tab
                    // item behind the sheet carries the same label.
                    .accessibilityIdentifier("logDose.submit")
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
        // The pins are for the rotation SUGGESTION only, so this read is allowed to fail
        // on its own without taking the sheet down with it — `try?`, deliberately. A
        // sheet that refuses to log a dose because it could not work out which muscle to
        // suggest would be trading the whole feature for the nicety.
        let backend = self.backend
        async let pinsTask = try? backend.doseLog(since: nil)
        do {
            let rows = try await backend.savedDosages()
            protocols = rows.filter(\.isActive)
            selectedId = protocols.first?.id
            pins = (await pinsTask) ?? []
        } catch {
            // Same load-cancellation rule as the view models — see LoadFailure. This one
            // reads `isCancellation` rather than `message` only because the string it
            // shows is fixed rather than the error's own; the decision is the same one.
            if !LoadFailure.isCancellation(error) { errorMessage = "Could not load your protocols." }
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
        // `siteForSelection` is the picker's own state, so what is written is exactly the
        // row the user can see ticked. It is nil only for a protocol with no track at
        // all — an oral steroid — and nil encodes as an ABSENT key, not a null, so that
        // case cannot blank a site already on the pin.
        let pin = NewDoseLogPin(for: dosage,
                                dosedOn: Self.dayFormatter.string(from: day),
                                site: siteForSelection)
        do {
            let written = try await backend.logDose(pin)
            // The house pattern on this table: commit off what the database RETURNED,
            // never off what was sent. A dose that reports "logged" while its site was
            // dropped is the exact defect this change exists to close, and the only
            // thing that can tell the two apart is the representation coming back.
            if pin.site != nil && written.site == nil {
                isSaving = false
                errorMessage = "That dose was logged, but without its injection site."
                return
            }
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
