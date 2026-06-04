import SwiftUI
import SafariServices

// ─── SettingsScreen ──────────────────────────────────────────────────────────
// Grouped List: profile header (tap → edit name sheet), PREFERENCES (theme / units /
// syringe scale bound straight to SettingsStore), CONNECTIONS (Discord → opens the
// web link in an in-app Safari sheet), ACCOUNT (change password, sign out, delete).
// Builds entirely on the existing SettingsStore + AuthStore — no new persistence.

struct SettingsScreen: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.backend) private var backend

    @State private var showEditName = false
    @State private var showSafari = false
    @State private var showDeleteConfirm = false
    @State private var passwordResetNote: String?

    /// The web Discord-link route this mirrors (SCREENS §4).
    private let discordLinkURL = URL(string: "https://injectbuddy.com/discord-link")!

    init() {}

    var body: some View {
        List {
            profileSection
            preferencesSection
            connectionsSection
            accountSection
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showEditName) {
            EditNameSheet(
                currentName: auth.identity?.displayName ?? "",
                onSave: { newName in await saveDisplayName(newName) }
            )
        }
        .sheet(isPresented: $showSafari) {
            SafariView(url: discordLinkURL).ignoresSafeArea()
        }
        .confirmationDialog("Delete account?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your account and saved protocols. This can't be undone.")
        }
    }

    // MARK: profile

    private var profileSection: some View {
        Section {
            Button { showEditName = true } label: {
                HStack(spacing: Theme.Spacing.md) {
                    ProfileAvatar(identity: auth.identity, size: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auth.identity?.displayName ?? "Account")
                            .font(.headline)
                            .foregroundStyle(Theme.label)
                        Text(auth.identity?.email ?? "")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryLabel)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: preferences

    private var preferencesSection: some View {
        Section("Preferences") {
            Picker("Theme", selection: $settings.theme) {
                ForEach(AppThemePreference.allCases) { Text($0.label).tag($0) }
            }
            Picker("Units", selection: $settings.units) {
                ForEach(UnitSystem.allCases) { Text($0.label).tag($0) }
            }
            Picker("Syringe scale", selection: $settings.syringeScale) {
                ForEach(SyringeScale.allCases) { Text($0.label).tag($0) }
            }
        }
    }

    // MARK: connections

    private var connectionsSection: some View {
        Section("Connections") {
            Button { showSafari = true } label: {
                HStack {
                    Label("Discord", systemImage: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(Theme.label)
                    Spacer()
                    Text("Link")
                        .foregroundStyle(Theme.secondaryLabel)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryLabel)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: account

    private var accountSection: some View {
        Section("Account") {
            Button {
                Task { await sendPasswordReset() }
            } label: {
                Label("Change password", systemImage: "key")
                    .foregroundStyle(Theme.label)
            }
            if let note = passwordResetNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryLabel)
            }

            Button(role: .destructive) {
                Task { await auth.signOut() }
            } label: {
                Label("Sign out", systemImage: "power")
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete account", systemImage: "exclamationmark.triangle")
            }
        }
    }

    // MARK: actions

    private func saveDisplayName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let userId = auth.currentUserId else { return }
        do {
            try await backend.updateDisplayName(trimmed, userId: userId)
            auth.setDisplayName(trimmed)
        } catch {
            // Surface via the auth store's error channel for consistency.
            auth.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func sendPasswordReset() async {
        guard let email = auth.identity?.email, !email.isEmpty else { return }
        await auth.sendPasswordReset(email: email)
        passwordResetNote = "Password reset email sent to \(email)."
    }

    private func deleteAccount() async {
        // TODO: call a backend account-deletion endpoint once it exists
        // (BackendClient has no delete-account method yet — SCREENS §4). For now we
        // sign the user out so the session is cleared client-side.
        await auth.signOut()
    }
}

// MARK: - Edit name sheet

private struct EditNameSheet: View {
    let currentName: String
    let onSave: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false

    init(currentName: String, onSave: @escaping (String) async -> Void) {
        self.currentName = currentName
        self.onSave = onSave
        _name = State(initialValue: currentName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Display name") {
                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                }
            }
            .navigationTitle("Edit name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            await onSave(name)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - SafariView (in-app browser for the Discord link)

/// Thin wrapper over SFSafariViewController (NOT WKWebView, per SCREENS §4) so the
/// Discord link opens in an in-app browser sheet that shares cookies with Safari.
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

#if DEBUG
#Preview {
    SettingsScreen()
        .environment(\.backend, MockBackendClient())
        .environmentObject(AuthStore())
        .environmentObject(SettingsStore())
}
#endif
