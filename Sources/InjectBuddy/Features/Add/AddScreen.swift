import SwiftUI

// ─── AddScreen / AddCategoryScreen ───────────────────────────────────────────
// The Add funnel, mirroring the web's /account/add/ (components/account/add/AddFlow.tsx):
//
//   "What are you adding?"  →  which calculator  →  the calculator  →  confirm start day
//
// The funnel exists so Add always has a defined start. Pressing Add ON a calculator
// with a finished result skips both of these steps entirely and goes straight to the
// confirm screen, because the two questions are already answered — that shortcut lives
// in CalculatorScreen, not here.
//
// Only savable calculators are offered. A picker that walks someone to a calculator
// with no save path strands them at the last step, so `savableMembers` filters them out
// and `visibleCases` hides any category left with nothing in it.

struct AddScreen: View {
    @EnvironmentObject private var navigator: ShellNavigator

    var body: some View {
        List {
            Section {
                ForEach(CalculatorCategory.visibleCases) { category in
                    Button {
                        navigator.push(.addCategory(category))
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: category.icon)
                                .frame(width: 26)
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.title).font(.body.weight(.semibold))
                                Text(category.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("What are you adding?")
            } footer: {
                Text("Pick a category to find the right calculator, fill it in, then add it to your protocols.")
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct AddCategoryScreen: View {
    let category: CalculatorCategory
    @EnvironmentObject private var navigator: ShellNavigator

    var body: some View {
        List {
            Section {
                ForEach(category.savableMembers) { slug in
                    Button {
                        navigator.push(.calculator(slug))
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: slug.icon)
                                .frame(width: 26)
                                .foregroundStyle(Theme.accent)
                            Text(slug.title).font(.body.weight(.semibold))
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Which calculator?")
            } footer: {
                Text("Fill it in, then press Add to save it and set the start day.")
            }
        }
        .listStyle(.insetGrouped)
    }
}
