import SwiftUI

// ─── ToolsScreen ─────────────────────────────────────────────────────────────
// The Tools tab: every calculator, grouped by category. The web's equivalent slot
// points at /calculators/, and this is the same idea — a browse surface, distinct
// from Add, which is a funnel with an outcome.
//
// Shows what `CalculatorCategory.members` offers, which is NOT every calculator, and
// this comment used to claim otherwise — it said the screen shows "ALL calculators
// including the ones that cannot save a protocol (BMI, Free T Index, the plotter)"
// while `members` had never enumerated the plotter at all. Two ways of being wrong in
// one sentence, so the shape is written down rather than a count:
//
//   - BMI and Free T Index are WITHDRAWN (H6, `CalculatorSlug.isListed`). The screens
//     and the engine are intact; only the links are gone.
//   - `Cycle Plotter` is absent because no category claims it — an open finding on the
//     board, not a decision, and not fixed here.
//
// Reads CalculatorCategory, which reads CalculatorSlug — the list is never restated.

struct ToolsScreen: View {
    @EnvironmentObject private var navigator: ShellNavigator

    var body: some View {
        List {
            ForEach(CalculatorCategory.allCases) { category in
                let members = category.members
                if !members.isEmpty {
                    // T-01e — THE SUBTITLE WAS ALREADY WRITTEN AND NEVER RENDERED.
                    // `CalculatorCategory.subtitle` defines all four strings
                    // ("Semaglutide, tirzepatide, retatrutide", "TRT, microdosing,
                    // HCG", …) and nothing in this file referenced it. Confirmed on
                    // both sides before building: a property with no reader.
                    //
                    // It is the third case found today of correct code that nothing
                    // calls — with `SteroidCatalog.canInject` (T-44) and the plotter's
                    // missing `members` entry (T-11). Worth watching as a pattern
                    // rather than three unrelated tasks.
                    Section {
                        ForEach(members) { slug in
                            row(slug)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.title)
                            Text(category.subtitle)
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryLabel)
                                .textCase(nil)
                                // A section header is not a place to lose words. No
                                // lineLimit anywhere in this file.
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// One calculator. T-01e: the web's cards carry two or three lines of description
    /// and iOS carried a title and an icon, on a list where `TRT Dose`, `TRT & EOD`
    /// and `TRT Microdose` are three different tools distinguished by one word.
    ///
    /// ONE accessibility element per row, combining the title and the description, so
    /// VoiceOver announces "TRT Dose, find your testosterone dose and injection
    /// volume" as a single stop rather than making the user swipe twice per row
    /// through thirty elements to browse fifteen calculators.
    private func row(_ slug: CalculatorSlug) -> some View {
        Button {
            navigator.push(.calculator(slug))
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Image(systemName: slug.icon)
                    // Inherits the surrounding text style rather than freezing a point
                    // size — the Tools-at-AX5 finding was icons staying small while the
                    // labels grew.
                    .foregroundStyle(Theme.tealTextStrong)
                    .frame(width: 28, alignment: .center)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(slug.title)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(slug.blurb)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryLabel)
                        // A calculator name is one of the two things CLAUDE.md says may
                        // never carry a lineLimit, and its description is what makes the
                        // name unambiguous — so it wraps too.
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: Theme.minTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("tool_\(slug.rawValue)")
        .accessibilityLabel("\(slug.title). \(slug.blurb)")
        .accessibilityAddTraits(.isButton)
    }
}
