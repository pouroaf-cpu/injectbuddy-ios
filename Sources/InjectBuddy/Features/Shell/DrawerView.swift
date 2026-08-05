import SwiftUI

// ─── DrawerView ──────────────────────────────────────────────────────────────
// The off-canvas drawer contents (iPhone): brand + profile header, primary items,
// all 14 calculators, settings, theme toggle, sign out. Items come from NavItems.
// DrawerList is the shared row list, reused by the iPad NavigationSplitView sidebar.

struct DrawerView: View {
    @EnvironmentObject private var navigator: ShellNavigator
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            DrawerList(selection: Binding(
                get: { navigator.route },
                set: { navigator.select($0) }
            ))
            Divider()
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ProfileAvatar(identity: auth.identity, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(auth.identity?.displayName ?? "Account")
                    .font(.headline)
                    .lineLimit(1)
                Text(auth.identity?.email ?? "")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .padding(.top, Theme.Spacing.lg)
        .contentShape(Rectangle())
        .onTapGesture { navigator.select(.settings) }
    }

    // No theme affordance: the app is light-only (UIUserInterfaceStyle=Light in
    // project.yml), so there is nothing to toggle. Sign out is now the only
    // footer action and gets the full row as its target — as a bare Label it was
    // a ~20pt tap area for a destructive action (audit finding F10).
    private var footer: some View {
        Button(role: .destructive) {
            Task { await auth.signOut() }
        } label: {
            Label("Sign out", systemImage: "power")
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .tint(Theme.danger)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
    }
}

// MARK: - Shared row list (drawer + iPad sidebar)

struct DrawerList: View {
    @Binding var selection: AppRoute

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(NavItems.sections) { section in
                    if let eyebrow = section.eyebrow {
                        Text(eyebrow.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.secondaryLabel)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.top, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.xs)
                    }
                    ForEach(section.routes, id: \.self) { route in
                        DrawerRow(route: route, isSelected: route == selection) {
                            selection = route
                        }
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.sm)
        }
    }
}

private struct DrawerRow: View {
    let route: AppRoute
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: route.icon)
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryLabel)
                Text(route.title)
                    .foregroundStyle(isSelected ? Theme.label : Theme.label.opacity(0.9))
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .fill(isSelected ? Theme.accentSoft : .clear)
                    .padding(.horizontal, Theme.Spacing.sm)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar (shared)

struct ProfileAvatar: View {
    let identity: AccountIdentity?
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let url = identity?.avatarURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsCircle
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.accent.opacity(0.35), lineWidth: 1.5))
    }

    private var initialsCircle: some View {
        Circle()
            .fill(Theme.accentSoft)
            .overlay(
                Text(identity?.initials ?? "··")
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            )
    }
}
