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
                    Section(category.title) {
                        ForEach(members) { slug in
                            Button {
                                navigator.push(.calculator(slug))
                            } label: {
                                Label(slug.title, systemImage: slug.icon)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
