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
    @EnvironmentObject private var network: NetworkMonitor
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
        // The dialog describes what the BUTTON DOES, which is sign out. It used to say
        // "This permanently removes your account and saved protocols. This can't be
        // undone." while `deleteAccount()` called `auth.signOut()` and nothing else —
        // no row deleted, no request sent, the account and every saved protocol intact
        // and waiting at the next sign-in. That is the app telling a user their data is
        // gone when it is not.
        //
        // Deletion itself is filed as launch-blocking (LAUNCH-CHECKLIST — Apple requires
        // an in-app deletion path for any app that creates accounts); this change is the
        // copy only, so the screen stops making a claim the code does not keep.
        .confirmationDialog("Sign out of this device?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Account deletion isn't available in the app yet. This signs you out on "
                 + "this device — your account and saved protocols are kept, and signing "
                 + "back in restores them. To have your account deleted, contact support.")
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
            // No theme control: the app is light-only (UIUserInterfaceStyle=Light
            // in project.yml). Its absence is a decision, not an omission.
            Picker("Units", selection: $settings.units) {
                ForEach(UnitSystem.allCases) { Text($0.label).tag($0) }
            }
            Picker("Syringe scale", selection: $settings.syringeScale) {
                ForEach(SyringeScale.allCases) { Text($0.label).tag($0) }
            }
        }
    }

    // MARK: connections

    // Preferences above are local-only (SettingsStore → UserDefaults) so they stay
    // fully usable offline; only these two sections talk to the backend, so they're
    // the ones that degrade — same "networked surface" treatment as Dashboard/
    // Calendar, just inline instead of a full-screen replacement since most of this
    // screen has nothing to do with the network at all.
    private var connectionsSection: some View {
        Section {
            Button { showSafari = true } label: {
                HStack {
                    Label("Discord", systemImage: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(network.isOnline ? Theme.label : Theme.secondaryLabel)
                    Spacer()
                    Text("Link")
                        .foregroundStyle(Theme.secondaryLabel)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryLabel)
                }
            }
            .buttonStyle(.plain)
            .disabled(!network.isOnline)
        } header: {
            Text("Connections")
        } footer: {
            if !network.isOnline {
                Text("You're offline — linking Discord needs a connection.")
            }
        }
    }

    // MARK: account

    private var accountSection: some View {
        Section {
            Button {
                Task { await sendPasswordReset() }
            } label: {
                Label("Change password", systemImage: "key")
                    .foregroundStyle(network.isOnline ? Theme.label : Theme.secondaryLabel)
            }
            .disabled(!network.isOnline)
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
            // Says so BEFORE the tap, not only inside the dialog. The row is the thing a
            // user scans for; leaving it to read as a working delete until they commit to
            // a destructive confirmation is the same false promise one screen later.
            Text("Account deletion isn't available in the app yet — contact support to "
                 + "have your account removed.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryLabel)
        } header: {
            Text("Account")
        } footer: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // `auth.lastError` was written by sendPasswordReset and by signOut and
                // rendered by NOTHING on this screen — AuthFlowView:63/:119 are the only
                // readers, and those are signed-out screens this user cannot be on. So a
                // failed password reset or a failed sign-out was silent here. This is the
                // render that makes the channel real.
                if let error = auth.lastError {
                    Text(error).foregroundStyle(Theme.danger)
                }
                if !network.isOnline {
                    Text("Password changes need a connection. Sign out still works offline.")
                }
            }
        }
    }

    // MARK: actions

    /// Returns nil when the name was written, or the message to show when it was not.
    ///
    /// It used to route the failure into `auth.lastError` "for consistency" — a property
    /// only AuthFlowView renders, and only on screens a signed-in user cannot reach. The
    /// sheet then dismissed regardless, so a save that changed no row (`profiles` has no
    /// row for a user who never had one written) looked exactly like a save that worked.
    /// The message goes back to the caller instead, which keeps the sheet open and shows
    /// it — the same shape as `LogDoseSheet.log()`.
    private func saveDisplayName(_ name: String) async -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Enter a name." }
        guard let userId = auth.currentUserId else {
            return "You're not signed in. Sign in again and retry."
        }
        do {
            // Throws `BackendWriteError.wroteNothing` when the UPDATE matched no row, so
            // the local identity below is only ever updated behind a write that landed.
            try await backend.updateDisplayName(trimmed, userId: userId)
            auth.setDisplayName(trimmed)
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func sendPasswordReset() async {
        guard let email = auth.identity?.email, !email.isEmpty else { return }
        passwordResetNote = nil
        auth.lastError = nil
        await auth.sendPasswordReset(email: email)
        // Only claim the mail went out if it went out. This line used to run
        // unconditionally after an await that swallows its failure into `lastError`, so
        // a rate-limited or offline reset still read "Password reset email sent to …"
        // and the user waited for mail that was never sent. AuthFlowView:213 has always
        // guarded the identical call this way; this is that guard, copied.
        guard auth.lastError == nil else { return }
        passwordResetNote = "Password reset email sent to \(email)."
    }

    private func deleteAccount() async {
        // Account deletion is NOT implemented and this method does not do it. Tracked as
        // launch-blocking in docs/LAUNCH-CHECKLIST.md — App Store Review Guideline 5.1.1(v)
        // requires an in-app deletion path for any app that lets users create an account.
        // Needs a backend endpoint first: BackendClient has no delete-account method, and
        // PostgREST + RLS cannot remove an auth.users row from the client.
        //
        // Until then this signs the user out, and the confirmation copy above says so
        // rather than promising a deletion that never happens.
        await auth.signOut()
    }
}

// MARK: - Edit name sheet

/// `onSave` returns nil on success, or the message to display on failure. The sheet
/// dismisses ONLY on nil — it used to dismiss unconditionally, which meant a save that
/// silently changed no row closed the sheet and left the old name on the screen behind
/// it with no explanation. Mirrors `LogDoseSheet`: await, then act on the outcome.
private struct EditNameSheet: View {
    let currentName: String
    let onSave: (String) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(currentName: String, onSave: @escaping (String) async -> String?) {
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
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(Theme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .navigationTitle("Edit name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") {
                            Task {
                                isSaving = true
                                errorMessage = nil
                                let failure = await onSave(name)
                                isSaving = false
                                if let failure {
                                    errorMessage = failure
                                } else {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
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
        .environmentObject(NetworkMonitor())
}
#endif
