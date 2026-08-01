import SwiftUI

// ─── Dashboard components ────────────────────────────────────────────────────
// Pure presentational views for the dashboard. Each takes plain data (no backend /
// view-model), so they preview in isolation and stay easy to restyle. The screen
// (DashboardScreen) wires these to the view-model.

// MARK: - Greeting headline

/// PWA `DashHeader.tsx:25` — 24px / weight 800 / -0.03em.
///
/// SHIPPED SOLID. Three attempts, three measurements, and the sweep does not survive
/// any of them on this SDK:
///   1. `.overlay { LinearGradient }.mask(Text)`      -> #5F6B6D
///   2. `.foregroundStyle(LinearGradient)`            -> #4B5557
///   3. 25 stops PRE-BLENDED in sRGB (`Theme.srgbStops`) -> #4A5456
/// against an expected #075E56, and a SOLID fill of that same colour renders
/// #095F57 correctly on the same screen in the same frame.
///
/// What the evidence actually says, which is narrower than "linear-light
/// interpolation": a gradient whose stops are all IDENTICAL renders exactly right,
/// and a gradient with two distinct stops renders desaturated — and pre-blending in
/// sRGB so that each segment spans a near-zero range does NOT help. So the fault
/// triggers on the presence of more than one distinct stop, not on the width of the
/// interpolation. That kills both available fixes: `LinearGradient` exposes no
/// colour-space control in the iOS 18.2 SDK (only `MeshGradient` takes a
/// `Gradient.ColorSpace`), and hand-blending does not avoid it.
///
/// Solid #075E56 is 7.65:1, the correct hue, and identical at every animation phase.
/// `Theme.srgbStops` is kept — it is correct and useful for fills, where the
/// desaturation is not visible against a dark surface — but not for text.
struct GreetingHeadline: View {
    let prefix: String
    let name: String

    private var text: String { "\(prefix), \(name)." }

    var body: some View {
        Text(text)
            .font(Theme.Typeface.greeting)
            .tracking(Theme.Typeface.greetingTracking)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(Theme.tealTextStrong)
            // The ONLY capped element in the app, and the rule it follows is in
            // DESIGN-PARITY §10: content scales without limit, decorative chrome may
            // be capped, and the test is whether a user acts on it. A greeting
            // carries no dose, no date and no state — nothing is lost reading it
            // smaller, and once the tokens started tracking Dynamic Type it took
            // roughly 40% of the dashboard at AX5 and pushed the next dose off
            // screen. Compare IB2245743.
            //
            // Do NOT cite this on anything a user acts on. The calculator names were
            // considered for the same treatment and rejected (DECISIONS D3) —
            // navigation into a dosing screen, and AX5 users are exactly who needs
            // them legible.
            //
            // VoiceOver is untouched: `dynamicTypeSize` caps the rendered size only,
            // and the accessibility label below is the full string either way.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityLabel(text)
    }
}

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

/// Full-width rows, not a 2-column grid.
///
/// The grid was not merely off-brand, it was unusable: every card carried
/// `.lineLimit(1)` on a title like "85mg/wk · Testosterone Enanthate" inside a
/// half-width column, so all seven truncated to "85mg/wk ·…" and two different
/// protocols both rendered "100mg/wk…". The compound name — the only thing that
/// distinguishes one row from another — was always the part inside the ellipsis.
///
/// Two changes fix it: full width, and the compound leads instead of the dose.
struct ProtocolGrid: View {
    let protocols: [DashboardProtocol]
    let onTap: (DashboardProtocol) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(protocols) { proto in
                ProtocolCard(protocol: proto) { onTap(proto) }
            }
        }
    }
}

struct ProtocolCard: View {
    let `protocol`: DashboardProtocol
    let onTap: () -> Void

    /// Backend labels arrive dose-first ("85mg/wk · Testosterone Enanthate").
    /// Split them so the compound is the headline and the dose is the meta line.
    /// Labels with no separator are used whole as the compound.
    private var parts: (compound: String, dose: String) {
        ProtocolLabel.split(`protocol`.title, fallbackDose: `protocol`.subtitle)
    }

    private var meta: String {
        let p = parts
        let sub = `protocol`.subtitle
        if sub.isEmpty { return p.dose }
        if p.dose.isEmpty || sub.contains(p.dose) { return sub }
        return "\(p.dose) · \(sub)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: `protocol`.slug?.icon ?? "syringe")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DashboardColor.color(for: `protocol`.slug))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                            .fill(DashboardColor.tint(for: `protocol`.slug))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    // No lineLimit(1). A compound name never gets truncated —
                    // it is the only thing that identifies the protocol.
                    Text(parts.compound)
                        .font(Theme.Typeface.cardTitle)
                        .foregroundStyle(Theme.inkNavy)
                        .fixedSize(horizontal: false, vertical: true)
                    if !meta.isEmpty {
                        Text(meta)
                            .font(Theme.Typeface.cardMeta)
                            .foregroundStyle(Theme.secondaryLabel)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: Theme.Spacing.sm)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.secondaryLabel)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card)
                            .stroke(Theme.line, lineWidth: 1)
                    )
            )
            // Per-compound colour spine down the leading edge, as the PWA runs on its
            // primary tile. Redundant with the icon chip's tint by design — it is
            // decoration reinforcing an identity the text already carries, never the
            // sole signal for anything.
            .overlay(alignment: .leading) {
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.Radius.card,
                    bottomLeadingRadius: Theme.Radius.card
                )
                .fill(DashboardColor.color(for: `protocol`.slug))
                .frame(width: 4)
                .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .contentShape(Rectangle())
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
    ///
    /// These are glyph colours on a pale tint, so WCAG 1.4.11 applies at 3:1 —
    /// the previous set (violet #8B5CF6, amber #F59E0B, blue #3B82F6, green
    /// #34D399, rose #F43F5E) was five saturated mid-tones off the brand ramp,
    /// several of them under 3:1. Replaced with deep brand-adjacent tones that
    /// clear 4.5:1 on white and still separate by hue.
    static func color(for slug: CalculatorSlug?) -> Color {
        guard let slug else { return Theme.tealTextStrong }
        switch slug {
        case .trt, .eod, .microdose: return Theme.tealTextStrong          // #075E56
        case .semaglutide, .tirzepatide, .retatrutide: return Theme.navy  // #001D5C
        case .hcg: return Color(hex: 0x8A5200)                            // deep amber
        case .peptide, .reconstitution: return Color(hex: 0x1D4ED8)       // deep blue
        case .bpc157, .bpc157blend: return Color(hex: 0x0F7A5F)           // deep green
        case .steroid: return Color(hex: 0xA31313)                        // deep rose
        case .bmi, .freeTestIndex, .cyclePlotter: return Theme.inkNavy
        }
    }

    /// Pale companion fill for the icon chip behind `color(for:)`.
    static func tint(for slug: CalculatorSlug?) -> Color {
        color(for: slug).opacity(0.10)
    }
}
