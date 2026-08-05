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
        // STEP 2 of 2. The row opens this; the destructive action is inside it and it
        // is not the default button. SPEC-ACCOUNT-DELETION §3.
        //
        // This copy promises a real deletion, and as of the `delete-account` Edge
        // Function that promise is kept. It previously said deletion was unavailable
        // BECAUSE it was: `deleteAccount()` called `auth.signOut()` and nothing else,
        // and an earlier version of the copy claimed a permanent removal while the
        // account and every saved protocol sat intact waiting for the next sign-in.
        // **Do not restore a promise here ahead of the code that keeps it.**
        .sheet(isPresented: $showDeleteConfirm) {
            DeleteAccountSheet(
                isOnline: network.isOnline,
                onDelete: { await deleteAccount() }
            )
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

            // STEP 1 of 2. Opens the confirm sheet; deletes nothing on its own.
            //
            // Apple requires deletion to be REACHABLE, not buried behind a support
            // contact or a survey (Guideline 5.1.1(v)). Two taps and a clear label is
            // the limit — do not add a reason picker, a retention offer or a cooling-off
            // step to this path.
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete account", systemImage: "exclamationmark.triangle")
            }
            .disabled(!network.isOnline)
            .accessibilityIdentifier("cta_delete_account")
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
                    Text("Password changes and account deletion need a connection. "
                         + "Sign out still works offline.")
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

    /// Returns nil when the account was deleted, or the message to show when it was not.
    ///
    /// **D9's sharpest case in this app.** The sheet stays open and shows the message on
    /// anything other than a confirmed success — a failed deletion that reads as success
    /// leaves a user believing their health data is gone when it is not. That is why the
    /// outcome comes back to the caller rather than going into `auth.lastError`, which
    /// nothing on this screen renders for a signed-in user.
    private func deleteAccount() async -> String? {
        guard network.isOnline else {
            return "You're offline. Nothing has been deleted — reconnect and try again."
        }
        do {
            // Throws unless the server confirmed every table, bucket prefix and the auth
            // user itself. Returns the storage prefixes whose files could not be removed;
            // that is NOT a failure — the account and every row are gone — so it is
            // logged rather than shown to a user who has no action to take.
            let storageFailures = try await backend.deleteAccount()
            if !storageFailures.isEmpty {
                // A developer convenience, and deliberately nothing more. **The durable
                // record of this lives in the Edge Function's logs**, which `console.error`
                // a structured line naming the uid and the failed prefixes — because this
                // client is about to lose its account, so anything it stored locally would
                // die with the app's data and there is no session left to upload it with.
                // A device cannot be the record for an event that happens as the device
                // ceases to be authenticated.
                print("[account-deletion] deleted, but files remain: \(storageFailures)")
            }
            // The auth user no longer exists, so the persisted session is already dead
            // server-side. This is what clears it from the Keychain — uninstalling would
            // not — and drops the app back to the auth gate.
            await auth.signOut()
            return nil
        } catch {
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Delete account sheet

/// Step 2 of 2. SPEC-ACCOUNT-DELETION §3: says plainly what will be deleted and that it
/// cannot be undone; the destructive action is the second tap and **is not the default
/// button** — Cancel is, and it is the one that reads as the way out.
///
/// `onDelete` returns nil on success, or the message to display on failure. **The sheet
/// dismisses only on nil.** Dismissing unconditionally would put the user back on a
/// Settings screen that looks exactly the same whether their account was destroyed or
/// nothing happened at all.
private struct DeleteAccountSheet: View {
    let isOnline: Bool
    let onDelete: () async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var errorMessage: String?

    /// Named individually rather than as "all your data". A user consenting to an
    /// irreversible deletion should be able to see what they are losing.
    private let deleted = [
        "Your saved protocols",
        "Your dose log and history",
        "Your cycles",
        "Your blood tests and uploaded files",
        "Your preferences and account details",
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(deleted, id: \.self) { item in
                        Label(item, systemImage: "trash")
                            .foregroundStyle(Theme.label)
                            // No lineLimit: a long row wraps rather than hiding what
                            // the user is agreeing to lose.
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("This deletes")
                } footer: {
                    Text("This cannot be undone. Your account is removed permanently and "
                         + "signing in again will not bring it back.")
                }

                Section {
                    Button(role: .destructive) {
                        Task {
                            isDeleting = true
                            errorMessage = nil
                            let failure = await onDelete()
                            isDeleting = false
                            if let failure {
                                errorMessage = failure
                            } else {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            if isDeleting { ProgressView().padding(.trailing, Theme.Spacing.xs) }
                            Text(isDeleting ? "Deleting…" : "Delete my account permanently")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(minHeight: Theme.minTarget)
                    }
                    .disabled(isDeleting || !isOnline)
                    .accessibilityIdentifier("cta_delete_account_confirm")
                } footer: {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        if let errorMessage {
                            Text(errorMessage).foregroundStyle(Theme.danger)
                        }
                        if !isOnline {
                            Text("You're offline — deleting an account needs a connection.")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Delete account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    // The way out, and the one that is NOT destructive.
                    Button("Cancel") { dismiss() }.disabled(isDeleting)
                }
            }
            .interactiveDismissDisabled(isDeleting)
        }
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
