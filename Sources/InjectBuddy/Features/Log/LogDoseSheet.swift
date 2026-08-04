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
//
// ── T-53: THE CARDS SAY WHAT THEY ARE ────────────────────────────────────────────
// The list rendered `label`, and iOS writes the calculator's static `saveTitle` into
// `label` on every save — so an account with two TRT protocols got "TRT Dose" twice,
// with nothing under either. They are legitimately distinct rows (the dedup index is
// `(user_id, calculator_type, config)`), which is exactly what made it dangerous: the
// user had to pick which dose to log by guessing. Every card now carries a line
// DERIVED FROM ITS CONFIG — see `ProtocolSummary`, which also guarantees no two lines
// in the list read the same. It replaces the label's dose half, which mixed three unit
// conventions in one list (S-04 #5); the derived line is per injection throughout.
//
// ── T-52: THE AMOUNT IS EDITABLE ─────────────────────────────────────────────────
// The sheet derived the dose and asked nothing, so a partial, split or adjusted dose
// went in as if it were the full one — the user's own history rounded to the plan, and
// every surface reading it (the serum curve, the supply ledger) modelling an injection
// that did not happen. There is now a DOSE AMOUNT field, seeded with the derived dose,
// written to `dose_log.dose_label`, and scaling `draw_ml` with it.

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

    /// What the user says they actually injected, per protocol, as typed. Keyed by
    /// protocol id for the same reason `chosenSite` is: the amount is in the protocol's
    /// OWN unit, so carrying "350" from a peptide across to a TRT row would offer to log
    /// 350 mg of testosterone.
    ///
    /// Held as the typed STRING, not a parsed Double. A half-typed "0." is not a number
    /// and must not become one behind the user's back, and re-formatting a field while
    /// it is being edited moves the caret.
    @State private var enteredAmount: [String: String] = [:]

    @FocusState private var amountFocused: Bool

    /// The supporting line under each card, resolved across the whole list so that no
    /// two cards read the same. Computed once per load rather than per row: it is a
    /// property of the LIST, not of a protocol.
    @State private var metaLines: [String: String] = [:]

    /// The protocol currently selected, if any.
    private var selectedProtocol: SavedDosage? {
        guard let selectedId else { return nil }
        return protocols.first { $0.id == selectedId }
    }

    /// The dose the calculator says one injection of the selected protocol delivers, or
    /// nil when it cannot be stated — a blend (two doses, no single one), a family this
    /// build cannot evaluate, or a config saved in a mode it does not run.
    private var derivedAmount: DoseAmount? {
        selectedProtocol.flatMap { ProtocolSummary.amount(for: $0) }
    }

    /// The amount that will be written: what the user typed, else the derived dose.
    ///
    /// Returns nil when the field holds something that is not a positive number — the
    /// CTA is disabled on that, because "log it anyway using the plan" would silently
    /// discard a correction the user is looking at.
    private var amountForSelection: DoseAmount? {
        guard let p = selectedProtocol, let derived = ProtocolSummary.amount(for: p) else { return nil }
        guard let typed = enteredAmount[p.id] else { return derived }
        let cleaned = typed.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(cleaned), value.isFinite, value > 0 else { return nil }
        return DoseAmount(value: value, unit: derived.unit)
    }

    /// Whether the sheet is in a state that can be committed. An amount field showing
    /// something unusable blocks the write; a protocol with no derivable amount does
    /// not, because that sheet shows no field to get wrong.
    private var canLog: Bool {
        guard selectedId != nil, network.isOnline else { return false }
        return derivedAmount == nil || amountForSelection != nil
    }

    /// The site that will be written: what the user picked, else the rotation's
    /// suggestion. nil only when this protocol has no track at all (an oral steroid).
    private var siteForSelection: String? {
        guard let p = selectedProtocol else { return nil }
        if let chosen = chosenSite[p.id] { return chosen }
        return InjectionSite.suggested(for: p, pins: pins, seed: protocols.firstIndex(of: p) ?? 0)
    }

    /// The heading for one card: the compound, never the dose half of the label.
    private func title(_ p: SavedDosage) -> String {
        let raw = p.label?.isEmpty == false ? p.label! : p.calculatorType
        return ProtocolLabel.split(raw).compound
    }

    /// One protocol, compound-first, in the calculator's field language.
    @ViewBuilder
    private func protocolRow(_ p: SavedDosage) -> some View {
        let heading = title(p)
        // The label's own dose half is NOT the fallback. It is what put `350mcg/inj`,
        // `300 mg/wk` and a blank in one list, and on the two rows this task is about it
        // is empty — the case where a fallback would be doing all the work.
        let meta = metaLines[p.id] ?? ProtocolSummary.line(for: p, title: heading)
        let isSelected = selectedId == p.id
        Button {
            selectedId = p.id
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(heading)
                        .font(Theme.Typeface.cardTitle)
                        .foregroundStyle(Theme.inkNavy)
                        .fixedSize(horizontal: false, vertical: true)
                    if !meta.isEmpty {
                        // No `lineLimit`, deliberately: this line carries doses and units,
                        // and a sheared "74.5 m" is a different dose rather than a clipped
                        // one. The container grows instead (UX-UI-RULES §2, §9).
                        Text(meta)
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
        .accessibilityIdentifier("logDose.protocol.\(p.id)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// **T-52 — what was actually injected.**
    ///
    /// Seeded with the derived dose, so the common case is "confirm the plan" and costs
    /// no typing. The unit is NOT editable and NOT part of the text field: it is a fact
    /// about the protocol, not about this injection, and a free-text unit is how "0.25"
    /// ends up meaning mL to one reader and mg to another.
    @ViewBuilder
    private func amountRow(_ p: SavedDosage, derived: DoseAmount) -> some View {
        let bad = amountForSelection == nil
        HStack(spacing: Theme.Spacing.sm) {
            TextField(derived.text, text: Binding(
                get: { enteredAmount[p.id] ?? derived.text },
                set: { enteredAmount[p.id] = $0 }
            ))
            .keyboardType(.decimalPad)
            .focused($amountFocused)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.ink)
            .accessibilityIdentifier("logDose.amount")
            .accessibilityLabel("Dose amount in \(derived.unit)")

            // The unit sits BESIDE the value at `sm 8` — side by side is the 8pt
            // relationship (UX-UI-RULES §4). It never truncates and never scales away:
            // a number that loses its unit is the worst failure this app has.
            Text(derived.unit)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: true, vertical: true)
        }
        .frame(minHeight: Theme.minTarget)
        .padding(.horizontal, Theme.Spacing.md)
        .fieldChrome(isFocused: amountFocused)
        .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md,
                                  bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)

        if bad {
            // Says why the CTA is off. Silently logging the plan instead would throw
            // away a correction the user is looking at, which is the whole defect.
            Text("Enter the amount you injected, in \(derived.unit).")
                .font(.footnote)
                .foregroundStyle(Theme.danger)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
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

                    // HOW MUCH. Rendered only when a per-injection dose can be derived:
                    // a blend delivers two doses and has no single amount, and a config
                    // saved in a mode this build does not evaluate has none it can state
                    // honestly. An empty box with no default would be worse than no box.
                    if let p = selectedProtocol, let derived = derivedAmount {
                        Section {
                            amountRow(p, derived: derived)
                        } header: {
                            Text("Dose amount".uppercased())
                                .font(Theme.Typeface.eyebrow)
                                .foregroundStyle(Theme.navy)
                                .textCase(nil)
                        } footer: {
                            Text("Defaults to this protocol's dose. Change it if you injected a different amount.")
                                .font(.footnote)
                                .foregroundStyle(Theme.secondaryLabel)
                        }
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
                        isEnabled: canLog
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
            // Resolved across the WHOLE list, which is why it is done here and not in
            // the row: "is this line unique" is a question about the list.
            metaLines = ProtocolSummary.lines(
                for: protocols,
                titles: Dictionary(uniqueKeysWithValues: protocols.map { ($0.id, title($0)) }))
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
        // A protocol with a derivable dose must produce a usable amount. The CTA is
        // already disabled on this, so reaching it means a race, not a typo — and
        // logging the plan instead of what the user typed is the defect, not the
        // fallback.
        let derived = ProtocolSummary.amount(for: dosage)
        let amount = amountForSelection
        if derived != nil && amount == nil { return }
        isSaving = true
        errorMessage = nil
        // `siteForSelection` is the picker's own state, so what is written is exactly the
        // row the user can see ticked. It is nil only for a protocol with no track at
        // all — an oral steroid — and nil encodes as an ABSENT key, not a null, so that
        // case cannot blank a site already on the pin.
        let pin = NewDoseLogPin(for: dosage,
                                dosedOn: Self.dayFormatter.string(from: day),
                                site: siteForSelection,
                                amount: amount)
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
            // Same contract for the amount, and it matters more: a dose recorded at the
            // planned amount when the user entered a different one is not a missing
            // field, it is a wrong number that reads as a right one.
            if let sent = pin.doseLabel, written.doseLabel != sent {
                isSaving = false
                errorMessage = "That dose was logged, but not at the amount you entered."
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
