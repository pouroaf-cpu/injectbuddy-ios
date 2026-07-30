import SwiftUI

// ─── Dashboard components ────────────────────────────────────────────────────
// Pure presentational views for the dashboard. Each takes plain data (no backend /
// view-model), so they preview in isolation and stay easy to restyle. The screen
// (DashboardScreen) wires these to the view-model.

// MARK: - Next dose card

struct NextDoseCard: View {
    let model: DashboardNextDose
    let now: Date
    let onMarkTaken: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("Next dose", systemImage: "syringe")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                if model.alreadyTaken {
                    Label("Taken", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.success)
                }
            }

            Text(model.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.label)

            HStack(spacing: Theme.Spacing.sm) {
                if !model.doseLine.isEmpty {
                    Text(model.doseLine).foregroundStyle(Theme.secondaryLabel)
                    Text("·").foregroundStyle(Theme.separator)
                }
                Text(Self.countdown(to: model.date, from: now))
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .font(.subheadline)

            if model.alreadyTaken {
                Text("Logged for \(model.occurrence.dayKey)")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryLabel)
            } else {
                PrimaryButton(title: "Mark taken", action: onMarkTaken)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// "due today", "due in 1d 4h", "overdue 2d" — coarse, friendly countdown.
    static func countdown(to date: Date, from now: Date) -> String {
        let secs = date.timeIntervalSince(now)
        if secs <= -86_400 {
            return "overdue \(Int((-secs) / 86_400))d"
        }
        if secs < 0 { return "due today" }
        let days = Int(secs / 86_400)
        let hours = Int((secs.truncatingRemainder(dividingBy: 86_400)) / 3_600)
        if days == 0 && hours == 0 { return "due now" }
        if days == 0 { return "due in \(hours)h" }
        return "due in \(days)d \(hours)h"
    }
}

// MARK: - Cycle timeline strip

struct CycleTimelineStrip: View {
    let progress: CycleProgress
    let occurrences: [DoseOccurrence]
    let now: Date

    private var days: [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let start = cal.startOfDay(for: now)
        return (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(days, id: \.self) { day in
                        DayPip(day: day,
                               isToday: isSameDay(day, now),
                               doses: doses(on: day))
                    }
                }
            }
            ProgressView(value: progress.fraction)
                .tint(Theme.accent)
            Text("Day \(progress.dayIndex) of \(progress.totalDays) · \(progress.name)")
                .font(.footnote)
                .foregroundStyle(Theme.secondaryLabel)
        }
        .card()
    }

    private func doses(on day: Date) -> [DoseOccurrence] {
        occurrences.filter { isSameDay($0.date, day) }
    }

    private func isSameDay(_ a: Date, _ b: Date) -> Bool {
        dpFormatDay(a) == dpFormatDay(b)
    }
}

private struct DayPip: View {
    let day: Date
    let isToday: Bool
    let doses: [DoseOccurrence]

    private var weekday: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "EEEEE" // single-letter weekday
        return f.string(from: day)
    }
    private var dayNumber: String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "d"
        return f.string(from: day)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(weekday)
                .font(.caption2)
                .foregroundStyle(Theme.secondaryLabel)
            Text(dayNumber)
                .font(.footnote.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Theme.accent : Theme.label)
            HStack(spacing: 2) {
                if doses.isEmpty {
                    Circle().fill(Color.clear).frame(width: 5, height: 5)
                } else {
                    ForEach(doses.prefix(3)) { occ in
                        Circle()
                            .fill(DashboardColor.color(for: occ.slug))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .frame(width: 34)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(isToday ? Theme.accentSoft : Color.clear)
        )
    }
}

// MARK: - Protocol grid

struct ProtocolGrid: View {
    let protocols: [DashboardProtocol]
    let onTap: (DashboardProtocol) -> Void

    private let columns = [GridItem(.flexible(), spacing: Theme.Spacing.md),
                           GridItem(.flexible(), spacing: Theme.Spacing.md)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.md) {
            ForEach(protocols) { proto in
                ProtocolCard(protocol: proto) { onTap(proto) }
            }
        }
    }
}

struct ProtocolCard: View {
    let `protocol`: DashboardProtocol
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: `protocol`.slug?.icon ?? "syringe")
                        .foregroundStyle(DashboardColor.color(for: `protocol`.slug))
                    Text(`protocol`.title)
                        .font(.headline)
                        .foregroundStyle(Theme.label)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(`protocol`.subtitle.isEmpty ? " " : `protocol`.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats island (week at a glance)

struct StatsIsland: View {
    let totals: [WeeklyTotal]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if totals.isEmpty {
                Text("No weekly totals yet")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryLabel)
            } else {
                ForEach(totals) { total in
                    HStack(spacing: Theme.Spacing.sm) {
                        Circle().fill(Theme.accent).frame(width: 6, height: 6)
                        Text(total.label)
                            .font(.subheadline)
                            .foregroundStyle(Theme.label)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Per-protocol colour (shared with calendar dots)

enum DashboardColor {
    /// Deterministic colour per calculator family so dots/cards read consistently.
    static func color(for slug: CalculatorSlug?) -> Color {
        guard let slug else { return Theme.accent }
        switch slug {
        case .trt, .eod, .microdose: return Theme.accent
        case .semaglutide, .tirzepatide, .retatrutide: return Color(hex: 0x8B5CF6) // violet
        case .hcg: return Color(hex: 0xF59E0B)        // amber
        case .peptide, .reconstitution: return Color(hex: 0x3B82F6) // blue
        case .bpc157, .bpc157blend: return Color(hex: 0x34D399)     // green
        case .steroid: return Color(hex: 0xF43F5E)                  // rose
        case .bmi, .freeTestIndex, .cyclePlotter: return Theme.secondaryLabel
        }
    }
}
