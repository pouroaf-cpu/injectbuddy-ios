import SwiftUI

// ─── CalendarScreen ──────────────────────────────────────────────────────────
// A month grid of projected injection days (dose dots coloured per protocol, today
// ringed), ‹ Today › month paging, and a DayAgenda for the tapped day. Tapping a
// dose toggles "taken" (optimistic). Loads via CalendarViewModel; renders off its
// LoadState. Projection window is 30 days but the grid renders full months so the
// strip reads naturally — days outside the window simply have no dots.

struct CalendarScreen: View {
    @EnvironmentObject private var navigator: ShellNavigator
    @EnvironmentObject private var network: NetworkMonitor
    @Environment(\.backend) private var backend

    @StateObject private var vm = CalendarViewModel()
    @State private var visibleMonth: Date = Date()

    init() {}

    var body: some View {
        content
            .background(Theme.groupedBackground.ignoresSafeArea())
            .task { await reload() }
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
                MonthGrid(
                    month: visibleMonth,
                    selectedDay: vm.selectedDay,
                    data: data,
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
                    onTap: { occ in Task { await vm.toggleTaken(occ, backend: backend) } }
                )
            }
            .padding(Theme.Spacing.md)
        }
    }

    private func reload() async {
        visibleMonth = Date()
        await vm.load(backend: backend)
    }

    private func shiftMonth(_ delta: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        if let next = cal.date(byAdding: .month, value: delta, to: visibleMonth) {
            withAnimation(.easeInOut(duration: 0.2)) { visibleMonth = next }
        }
    }

    private func goToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            visibleMonth = Date()
            vm.selectedDay = {
                var cal = Calendar(identifier: .gregorian)
                cal.timeZone = TimeZone(identifier: "UTC")!
                return cal.startOfDay(for: Date())
            }()
        }
    }
}

// MARK: - Month grid

struct MonthGrid: View {
    let month: Date
    let selectedDay: Date
    let data: CalendarData
    let onPrev: () -> Void
    let onToday: () -> Void
    let onNext: () -> Void
    let onSelect: (Date) -> Void

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
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
                            isToday: isSameDay(day, Date()),
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
            Text(monthLabel)
                .font(.headline)
            Spacer()
            Button(action: onPrev) { Image(systemName: "chevron.left") }
            Button("Today", action: onToday)
                .font(.subheadline.weight(.medium))
            Button(action: onNext) { Image(systemName: "chevron.right") }
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
    }
}

// MARK: - Day agenda

struct DayAgenda: View {
    let day: Date
    let occurrences: [DoseOccurrence]
    let isTaken: (DoseOccurrence) -> Bool
    let onTap: (DoseOccurrence) -> Void

    private var dayLabel: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "EEE d MMM"
        return f.string(from: day)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Selected · \(dayLabel)".uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryLabel)

            if occurrences.isEmpty {
                Text("No doses scheduled")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.vertical, Theme.Spacing.sm)
            } else {
                ForEach(occurrences) { occ in
                    AgendaRow(occurrence: occ, taken: isTaken(occ)) { onTap(occ) }
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(taken ? Theme.success : Theme.secondaryLabel)
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
