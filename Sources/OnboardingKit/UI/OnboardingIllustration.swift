import SwiftUI

// ─── ILLUSTRATIONS — NONE OF THEM EXIST ──────────────────────────────────────
//
// SPEC §5: "Every benefit screen and several others carry an illustration. NONE
// OF THEM EXIST. Ship this pass with a labelled placeholder that reserves the
// real aspect ratio, and record the list as its own task."
//
// SPEC §5, both halves, and the second one is the one that bites:
//   "Do not let placeholder art block the flow landing."
//   "DO NOT LET A PLACEHOLDER SHIP TO THE STORE."
//
// The placeholder is drawn to be impossible to mistake for art: a dashed
// warning-coloured box with the words PLACEHOLDER — NOT FOR SHIP and the asset
// name on it. If one of these reaches a screenshot, the screenshot says so.

/// The fifteen illustrations SPEC §5 lists, in the order it lists them.
enum OnboardingIllustration: String, CaseIterable, Hashable {
    case flatLevelsChart        // "flat levels chart"
    case chartPlusShareIcon     // "chart + share icon"
    case levelsOverTimeChart    // "levels-over-time chart"
    case reconstitutionCalc     // "reconstitution calc"
    case dollarPlusTrendLine    // "$ + trend line"
    case streakCalendar         // "streak calendar"
    case multiCompoundCurve     // "multi-compound curve"
    case cyclePlotter           // "cycle plotter"
    case lock                   // "lock"
    case multiProtocolView      // "multi-protocol view"
    case halfLifeCurve          // "half-life curve"
    case bodyMap                // "body map"
    case bigLogButtonSyringe    // "big log button / syringe"
    case logoCelebration        // "logo-celebration"
    case photoOfPou             // "photo of Pou"

    /// The spec's own wording, for the placeholder label and for the asset task.
    var specName: String {
        switch self {
        case .flatLevelsChart:     return "flat levels chart"
        case .chartPlusShareIcon:  return "chart + share icon"
        case .levelsOverTimeChart: return "levels-over-time chart"
        case .reconstitutionCalc:  return "reconstitution calc"
        case .dollarPlusTrendLine: return "$ + trend line"
        case .streakCalendar:      return "streak calendar"
        case .multiCompoundCurve:  return "multi-compound curve"
        case .cyclePlotter:        return "cycle plotter"
        case .lock:                return "lock"
        case .multiProtocolView:   return "multi-protocol view"
        case .halfLifeCurve:       return "half-life curve"
        case .bodyMap:             return "body map"
        case .bigLogButtonSyringe: return "big log button / syringe"
        case .logoCelebration:     return "logo-celebration"
        case .photoOfPou:          return "photo of Pou"
        }
    }

    /// **PROVISIONAL — confirmed against the wireframe 2026-08-03 by the Windows
    /// side, which is the only machine that can read it.** The placeholder is
    /// **full content width with a 90pt minimum height, and it may grow** —
    /// a wide banner, roughly 4:1 at the wireframe's own dimensions.
    ///
    /// This replaces a 4:3 holding value that had no evidence behind it. A
    /// guessed shape makes every screen re-judge *worse* rather than better,
    /// because it looks like a decision. Full-width × 90pt minimum is the one
    /// dimension the source actually gives.
    ///
    /// Still provisional until the art is commissioned — but provisional-with-a-
    /// source is not the same as UNKNOWN, and only the latter needs re-deriving.
    static let minHeight: CGFloat = 90

    // MARK: - Which screen carries which
    //
    // **CONFIRMED against the wireframe, 2026-08-03, read by the Windows side**
    // — the only machine that can open the source files. The wireframe carries a
    // literal placeholder on each screen and they land exactly here.
    //
    // This was previously reconstructed by inference — the list's own order laid
    // against §4's screen order, which fit exactly. Fitting exactly is
    // suggestive and is not proof, so it was marked as a guess until someone
    // read the source. **It is now stated, and an art brief can be built on it.**
    //
    // Twelve benefits plus three: firstDose, welcome, and the paywall's founder
    // note. Fifteen, and that is the whole list.
    //
    // **The `dashboard` end state's three placeholders are NOT part of the
    // fifteen and must never reach the art list** — active levels chart, next
    // dose card and cycle plotter pre-loaded are MOCKS OF REAL UI, not
    // illustrations to commission.

    static func forBenefit(segment: OnboardingSegment, index: Int) -> OnboardingIllustration? {
        let set: [OnboardingIllustration]
        switch segment {
        case .trt:   set = [.flatLevelsChart, .chartPlusShareIcon, .levelsOverTimeChart]
        case .glp:   set = [.reconstitutionCalc, .dollarPlusTrendLine, .streakCalendar]
        case .aas:   set = [.multiCompoundCurve, .cyclePlotter, .lock]
        case .other: set = [.multiProtocolView, .halfLifeCurve, .bodyMap]
        }
        guard set.indices.contains(index) else { return nil }
        return set[index]
    }

    /// The non-benefit screens that carry art. Enumerated over every step.
    static func forStep(_ step: OnboardingStep) -> OnboardingIllustration? {
        switch step {
        case .welcome:   return .logoCelebration
        case .firstDose: return .bigLogButtonSyringe
        case .paywall:   return .photoOfPou
        case .pathway, .experience, .setup, .reminders, .inventory,
             .dashboard, .locked:
            return nil
        // The benefit screens go through `forBenefit(segment:index:)` — the
        // asset depends on the segment, which this function does not have.
        case .benefit1, .benefit2, .benefit3:
            return nil
        }
    }
}

// MARK: - The placeholder view

/// **PLACEHOLDER ART. MUST NOT SHIP.**
///
/// Reserves space and labels itself. Delete this type the moment real assets
/// land; the compile errors it leaves behind are the checklist.
struct OnboardingIllustrationPlaceholder: View {
    let illustration: OnboardingIllustration

    private static let warningLabel = "PLACEHOLDER — NOT FOR SHIP"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.warning.opacity(0.08))
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(
                    Theme.warning,
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
            VStack(spacing: Theme.Spacing.xs) {
                Text(Self.warningLabel)
                    .font(.caption2.weight(.bold))
                Text(illustration.specName)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.warning)
            .padding(Theme.Spacing.sm)
        }
        .frame(maxWidth: .infinity, minHeight: OnboardingIllustration.minHeight, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.warningLabel): \(illustration.specName)")
    }
}
