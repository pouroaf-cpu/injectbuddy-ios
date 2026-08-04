import SwiftUI

// ─── CalendarScreen ──────────────────────────────────────────────────────────
// A month grid of scheduled injection days (dose dots coloured per protocol, today
// ringed), ‹ Today › month paging, and a DayAgenda for the tapped day. Tapping a
// dose toggles "taken". Loads via CalendarViewModel; renders off its LoadState.
//
// ─── T-09. THE PARAGRAPH THAT USED TO BE HERE DESCRIBED THE DEFECT AS A DESIGN ───
//
// It read: *"Projection window is 30 days but the grid renders full months so the
// strip reads naturally — days outside the window simply have no dots."* Every clause
// of that is true and the conclusion is a dosing error. A day with no dots is how this
// grid says NOTHING IS DUE. Past day 30 it drew the same cell for "nothing is due" and
// for "nobody asked" — so the screen answered a question it had not looked at, and
// answered it "no". Five of the seven months a web user can page to were blank here.
//
// There is no window any more. `CalendarViewModel` holds SCHEDULES and answers per
// date (see the T-09 note there), so every cell this grid draws has been asked. The
// only bound left is which months a user can PAGE to — `CalendarWindow.offsets`,
// which is the web's own `-1…+5` from `CalendarView.tsx:311-320` — and that is a
// rendering bound with no effect on what a rendered day says.
//
// The chevrons are DISABLED at the ends rather than paging into months the pin fetch
// does not cover. A dead-ended chevron says "this is as far as it goes"; a chevron
// that keeps going into months whose taken-state was never fetched would put untaken
// ticks on doses the user has logged, which is the same defect wearing the other sign.

struct CalendarScreen: View {
    @EnvironmentObject private var navigator: ShellNavigator
    @EnvironmentObject private var network: NetworkMonitor
    @Environment(\.backend) private var backend

    @StateObject private var vm = CalendarViewModel()
    /// A day TOKEN, never a bare instant. `Date()` is a moment; the month it belongs to
    /// is a question about the viewer's zone, and reading it on the token frame's UTC
    /// calendar named the previous month for the first hours of every day east of UTC
    /// (T-82). `dpDayToken` asks locally, then hands back a token so the grid's day
    /// arithmetic below stays zone-free.
    @State private var visibleMonth: Date = dpDayToken(Date())

    init() {}

    var body: some View {
        content
            .background(Theme.groupedBackground.ignoresSafeArea())
            .task { await reload() }
            // ─── T-05, THE EXPERIMENT ────────────────────────────────────────────
            //
            // DEBUG-ONLY and OFF unless `T05_EXPERIMENT=1`, so the affordance that was
            // removed for lying is not quietly restored by the thing measuring it.
            // With the flag set, the pull is armed again and `t05_reloads` below
            // publishes how many times `reload()` actually ran.
            //
            // The point is to kill candidate (A) one way or the other. The flag
            // `CALENDAR_INLINE_TITLE=1` (see `RouteContent.titleDisplayMode`) flips
            // THIS screen's navigation title to `.inline`, which is the dashboard's
            // setting and the one difference between the two roots. One build, two
            // conditions, run twice:
            //
            //   T05_EXPERIMENT=1                          → pull, expect NO increment
            //                                               (reproduces the defect)
            //   T05_EXPERIMENT=1 CALENDAR_INLINE_TITLE=1  → pull, expect +1
            //                                               (candidate A confirmed)
            //
            // Both conditions matter and the RED one matters more. A run that only
            // shows the fix working cannot tell "inline title fixes it" from "the pull
            // works now for some other reason" — and batch 4 already changed something
            // in this area (`load` no longer blanks to `.loading`), so "it just works
            // now" is a live possibility that this design can distinguish and a
            // one-condition run cannot.
            .modifier(T05PullExperiment(isOn: Self.t05Enabled) { await reload() })
            .overlay { t05Probe }
        // ─── NO `.refreshable` HERE, AND IT IS DELIBERATE. UNSOLVED — filed. ──────
        //
        // `.refreshable { await reload() }` stood on this line and **fired nothing**.
        // Removed 2026-08-03 rather than left in place: a pull that silently does
        // nothing is worse than no pull, because the user believes they refreshed and
        // they have not — the same lie as the optimistic tick, on the screen that
        // records what has actually been injected.
        //
        // MEASURED, not reasoned (sweep 3, `Sweep3UITests` A5/A6):
        //   • Calendar parked, untouched. A production label change made 56s before the
        //     pull never appeared, and Supabase's API log — an observer outside the app
        //     and outside the suite — shows ZERO requests after the initial read.
        //   • THE DISCRIMINATOR: the same gesture, one minute apart in the same run, on
        //     two identically-shaped ScrollViews. Dashboard pull → re-read visible in
        //     the API log within 3s. Calendar pull → nothing. So the drag arms
        //     `.refreshable` fine; the Calendar is the difference.
        //
        // The two screens' own source is the same shape, so THE CAUSE IS NOT VISIBLE
        // FROM A SOURCE READ and nobody should try to find it in one again. Three
        // candidates, none of them measured — whoever picks this up starts by killing
        // one, on the device:
        //
        //   (A) THE STRONGEST, and it is one level up rather than in either screen —
        //       which is exactly why comparing these two files shows nothing.
        //       `RouteContent.titleDisplayMode` gives the dashboard `.inline` and every
        //       other tab root, this one included, a LARGE navigation title. A large
        //       title owns the pull-down stretch above a plain ScrollView, and the
        //       dashboard is the ONLY root that does not have one.
        //   (B) The harness's `scrollContainer()` takes the first hittable scroll-ish
        //       element, and this screen has a LazyVGrid the dashboard does not. "Same
        //       gesture" was established; "same target element" was not.
        //   (C) `reload()` below mutates `visibleMonth` (@State) BEFORE its await;
        //       `DashboardScreen.reload()` awaits immediately.
        //
        // ALSO UNMEASURED, and the cheapest thing to try first: batch 4 item 1 stopped
        // `CalendarViewModel.load` blanking to `.loading` on a refresh, so the ScrollView
        // that owns the refresh control is no longer destroyed underneath it mid-pull.
        // If that was the cause, this affordance comes back by restoring one line — but
        // it comes back on a MEASUREMENT (a request in the API log), never on the
        // argument above.
        //
        // NOTHING IS LOST FROM THE DATA PATH: `.task` re-runs on tab re-appearance, so
        // the calendar still re-reads. Only the affordance is gone, and it was an
        // affordance that did not work.
        // ─────────────────────────────────────────────────────────────────────────
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .loading:
            LoadingView()
        case .failed(let message):
            // Same reasoning as DashboardScreen: no cache + offline is the
            // design's dedicated offline screen, not a generic error banner.
            if network.isOnline {
                ErrorBanner(message: message) { Task { await reload() } }
            } else {
                OfflineView { Task { await reload() } }
            }
        case .empty:
            EmptyStateView(
                systemImage: "calendar",
                title: "Nothing scheduled",
                message: "Add a protocol to see your injection schedule here.",
                actionTitle: "Add a protocol",
                action: { navigator.push(.calculator(.trt)) }
            )
        case .loaded(let data):
            loaded(data)
        }
    }

    private func loaded(_ data: CalendarData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // The loaded branch is the one on screen when a toggle fails, so this is
                // where the failure has to appear. `vm.state` stays the LOAD channel:
                // pushing a toggle failure into `.failed` would swap the whole calendar
                // for a banner (or, offline, for OfflineView) over one tapped dose.
                if let actionError = vm.actionError {
                    InlineErrorNote(message: actionError) { vm.actionError = nil }
                }

                MonthGrid(
                    month: visibleMonth,
                    selectedDay: vm.selectedDay,
                    data: data,
                    canGoPrev: CalendarWindow.offsets.contains(visibleMonthOffset - 1),
                    canGoNext: CalendarWindow.offsets.contains(visibleMonthOffset + 1),
                    onPrev: { shiftMonth(-1) },
                    onToday: { goToday() },
                    onNext: { shiftMonth(1) },
                    onSelect: { vm.selectedDay = $0 }
                )
                .card()

                DayAgenda(
                    day: vm.selectedDay,
                    occurrences: data.occurrences(on: vm.selectedDay),
                    isTaken: { data.isTaken($0) },
                    isPending: { vm.pendingKey == "\($0.protocolId)@\($0.dayKey)" },
                    onTap: { occ in Task { await vm.toggleTaken(occ, backend: backend) } }
                )
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func reload() async {
        visibleMonth = dpDayToken(Date())
        // Counted BEFORE the await, so a reload that starts and never returns is
        // still visible. The question T-05 asks is whether the closure runs AT ALL —
        // the previous measurement could only see requests that reached Supabase, so
        // "the closure never fired" and "it fired and the request was suppressed
        // downstream" were indistinguishable from outside. This separates them.
        t05Reloads += 1
        await vm.load(backend: backend)
    }

    // MARK: - T-05 experiment plumbing (DEBUG only, not compiled into Release)

    @State private var t05Reloads: Int = 0

    static var t05Enabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["T05_EXPERIMENT"] == "1"
        #else
        return false
        #endif
    }

    /// Publishes the reload count, and the two flags it was taken under — so a frame
    /// or an assertion cannot be filed against a condition the app never saw. The
    /// same rule `bar_gate` follows, and for the same reason: this project has already
    /// filed evidence gathered under a setting that never arrived.
    @ViewBuilder
    private var t05Probe: some View {
        #if DEBUG
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityElement()
            .accessibilityIdentifier("t05_probe")
            .accessibilityLabel("reloads=\(t05Reloads) "
                                + "experiment=\(Self.t05Enabled) "
                                + "inline=\(RouteContent.calendarInlineTitleOverride) "
                                // The four that separate "never sent" from "sent and
                                // died" — see CalendarViewModel's note at its `catch`.
                                + "entered=\(vm.t05Entered) "
                                + "requested=\(vm.t05Requested) "
                                + "returned=\(vm.t05Returned) "
                                + "threw=\(vm.t05Threw) "
                                + "err=\(vm.t05LastError)")
        #endif
    }

    /// How far the shown month is from the current one. The single number both chevrons
    /// clamp against, so "can I page there" and "did I page there" are the same
    /// arithmetic.
    private var visibleMonthOffset: Int {
        CalendarWindow.monthOffset(of: visibleMonth, from: dpDayToken(Date()))
    }

    private func shiftMonth(_ delta: Int) {
        let target = visibleMonthOffset + delta
        // Clamped at the source and not only on the buttons' `disabled`. A disabled
        // control is a hint; this is the rule. Anything that can call `shiftMonth` —
        // a future gesture, a deep link, a test — gets the same answer.
        guard CalendarWindow.offsets.contains(target) else { return }
        if let next = CalendarWindow.utc.date(byAdding: .month, value: delta, to: visibleMonth) {
            withAnimation(.easeInOut(duration: 0.2)) { visibleMonth = next }
        }
    }

    private func goToday() {
        let today = dpDayToken(Date())
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = today
            vm.selectedDay = today
        }
    }
}

// MARK: - Month grid

struct MonthGrid: View {
    let month: Date
    let selectedDay: Date
    let data: CalendarData
    /// Whether the month one step back / forward is inside `CalendarWindow.offsets`.
    /// Passed in rather than derived here so the grid and the screen cannot disagree
    /// about where the ends are.
    var canGoPrev: Bool = true
    var canGoNext: Bool = true
    let onPrev: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void
    let onSelect: (Date) -> Void

    private var cal: Calendar {
        var c = CalendarWindow.utc
        c.firstWeekday = 2 // Monday, matching the wireframe header
        return c
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            header
            weekdayRow
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        DayCell(
                            day: day,
                            // Was `isSameDay(day, Date())`, i.e. `dpFormatDay(Date())` —
                            // the exact call T-82's own note forbids, since it asks the
                            // zone-less token formatter which day an INSTANT falls on.
                            // The ring sat on yesterday's cell for the first twelve hours
                            // of every Auckland day. See `CalendarWindow.isToday`.
                            isToday: CalendarWindow.isToday(day),
                            isSelected: isSameDay(day, selectedDay),
                            doses: data.occurrences(on: day),
                            onTap: { onSelect(day) }
                        )
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            // Identified so a run can assert WHICH month it is looking at before it
            // asserts anything about the cells. Three frames in the old archive were
            // photographs of the previous screen; a month grid photographed after a
            // chevron tap that did not land is the same failure, and this is what
            // closes it.
            Text(monthLabel)
                .font(.headline)
                .accessibilityIdentifier("calendar_month")
            Spacer()
            Button(action: onPrev) { Image(systemName: "chevron.left") }
                .accessibilityIdentifier("calendar_prev_month")
                .accessibilityLabel("Previous month")
                .disabled(!canGoPrev)
            Button("Today", action: onToday)
                .font(.subheadline.weight(.medium))
            Button(action: onNext) { Image(systemName: "chevron.right") }
                .accessibilityIdentifier("calendar_next_month")
                .accessibilityLabel("Next month")
                .disabled(!canGoNext)
        }
        .tint(Theme.accent)
    }

    private var weekdayRow: some View {
        HStack {
            ForEach(["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"], id: \.self) { d in
                Text(d)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: month)
    }

    /// Days of the month padded with leading nils so the 1st lands on its weekday.
    private var gridDays: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: month))
        else { return [] }
        // Leading blanks: weekday offset from Monday.
        let weekday = cal.component(.weekday, from: first) // 1=Sun…7=Sat
        let leading = (weekday - cal.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: first) { cells.append(d) }
        }
        return cells
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool { dpFormatDay(a) == dpFormatDay(b) }
}

struct DayCell: View {
    let day: Date
    let isToday: Bool
    let isSelected: Bool
    let doses: [DoseOccurrence]
    let onTap: () -> Void

    private var dayNumber: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "d"
        return f.string(from: day)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.footnote.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? Theme.accent : Theme.label)
                HStack(spacing: 2) {
                    ForEach(doses.prefix(3)) { occ in
                        Circle()
                            .fill(DashboardColor.color(for: occ.slug))
                            .frame(width: 5, height: 5)
                    }
                    if doses.isEmpty {
                        Circle().fill(Color.clear).frame(width: 5, height: 5)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(isSelected ? Theme.accentSoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .stroke(isToday ? Theme.accent : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // ─── The dose count, in words, on every cell ─────────────────────────────
        //
        // The dots are the whole answer this cell gives and NOT ONE of them reached the
        // accessibility tree: the cell read "17" whether a dose was due or not. Same
        // defect `AgendaRow` already carries a note about, on the surface that is meant
        // to be scannable — a VoiceOver user could not tell a dose day from an empty one
        // on the calendar at all.
        //
        // It is also what makes T-09 assertable rather than merely photographable. "0
        // doses" and "2 doses" are different strings; a blank cell and a not-calculated
        // cell were the same pixels, which is exactly why the defect survived being
        // looked at. A run can now read the answer instead of reading the picture.
        //
        // A VALUE, not a longer label, for the reason given at `AgendaRow`: it is this
        // cell's state, and it arrives in `XCUIElement.value` where a test can take it.
        .accessibilityIdentifier("day_\(dpFormatDay(day))")
        .accessibilityValue(doses.count == 1 ? "1 dose" : "\(doses.count) doses")
    }
}

// MARK: - Day agenda

struct DayAgenda: View {
    let day: Date
    let occurrences: [DoseOccurrence]
    let isTaken: (DoseOccurrence) -> Bool
    /// True for the row whose write is in flight. The tick no longer moves ahead of the
    /// database, so a row with no spinner and no tick means nothing has been recorded.
    var isPending: (DoseOccurrence) -> Bool = { _ in false }
    let onTap: (DoseOccurrence) -> Void

    private var dayLabel: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "EEE d MMM"
        return f.string(from: day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Identified for the same reason as `calendar_month`: it is the proof of
            // WHICH day an agenda belongs to, and without it a frame of the agenda is a
            // frame of whatever day was selected last.
            Text("Selected · \(dayLabel)".uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryLabel)
                .accessibilityIdentifier("agenda_header")

            if occurrences.isEmpty {
                Text("No doses scheduled")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                ForEach(occurrences) { occ in
                    AgendaRow(occurrence: occ, taken: isTaken(occ), pending: isPending(occ)) {
                        onTap(occ)
                    }
                }
                Text("Tap a dose to mark it taken")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct AgendaRow: View {
    let occurrence: DoseOccurrence
    let taken: Bool
    var pending: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                if pending {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Saving")
                } else {
                    Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(taken ? Theme.success : Theme.secondaryLabel)
                }
                Circle()
                    .fill(DashboardColor.color(for: occurrence.slug))
                    .frame(width: 8, height: 8)
                Text(occurrence.label)
                    .font(.subheadline)
                    .foregroundStyle(Theme.label)
                    .strikethrough(taken, color: Theme.secondaryLabel)
                Spacer(minLength: 0)
                if let slug = occurrence.slug {
                    Text(slug.shortTitle)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryLabel)
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // "Logged" is carried by an SF Symbol, a colour and a strikethrough, and NOT ONE
        // of those reaches the accessibility label: this row read "TRT Dose, TRT" whether
        // the dose was taken or not. In a dosing app that means a VoiceOver user cannot
        // tell a taken dose from an untaken one — and it is why the last sweep had to
        // query the database to observe a tick that is right there on screen.
        //
        // A VALUE rather than a longer label: it is this control's STATE, VoiceOver
        // re-announces it on change without re-reading the whole row, and it arrives in
        // `XCUIElement.value` where a run can read it directly.
        //
        // Minimal on purpose. This is not the deferred accessibility work — one site.
        .accessibilityValue(pending ? "Saving" : (taken ? "Taken" : "Not taken"))
    }
}

#if DEBUG
#Preview("Loaded") {
    CalendarScreen()
        .environment(\.backend, MockBackendClient())
        .environmentObject(ShellNavigator())
        .environmentObject(NetworkMonitor())
}

#Preview("Empty") {
    CalendarScreen()
        .environment(\.backend, MockBackendClient(dosages: [], cycles: []))
        .environmentObject(ShellNavigator())
        .environmentObject(NetworkMonitor())
}
#endif

/// Applies `.refreshable` only when the T-05 experiment is on.
///
/// A modifier rather than an `if` in the body, and the reason is the experiment's
/// own validity: `.refreshable` changes the view's identity, so branching the whole
/// `content` on a flag would swap the ScrollView out from under the refresh control
/// — which is one of the three mechanisms T-05 lists as a possible cause of the
/// original defect. An experiment must not contain the thing it is testing for.
private struct T05PullExperiment: ViewModifier {
    let isOn: Bool
    let action: () async -> Void

    func body(content: Content) -> some View {
        if isOn {
            content.refreshable { await action() }
        } else {
            content
        }
    }
}
