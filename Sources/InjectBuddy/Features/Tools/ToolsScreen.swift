import SwiftUI

// ─── ToolsScreen ─────────────────────────────────────────────────────────────
// The Tools tab: every calculator, grouped by category. The web's equivalent slot
// points at /calculators/, and this is the same idea — a browse surface, distinct
// from Add, which is a funnel with an outcome.
//
// Shows ALL calculators including the ones that cannot save a protocol (BMI, Free T
// Index, the plotter). That is the difference between the two screens: browsing has
// no outcome to be blocked from, so nothing needs hiding here.
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
