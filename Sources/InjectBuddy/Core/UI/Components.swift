import SwiftUI

// ─── Shared UI components ────────────────────────────────────────────────────
// Small building blocks reused across auth, dashboard, calculators, calendar, and
// settings so the app stays visually consistent. Teal accent, system materials.

// MARK: - Buttons

struct PrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isLoading ? 0 : 1)
                if isLoading { ProgressView().tint(.white) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
            .padding(.vertical, 14)
            // Navy is the action colour: every primary CTA and the hero share it,
            // so "this is the thing to press" is one colour app-wide. White on
            // #001D5C is 15.79:1, up from #075E56's 7.65:1.
            // (Contrast is symmetric, which is why "make it a filled teal button"
            // never fixed anything on its own: white on #0FBCAD is the same 2.38:1
            // as #0FBCAD text on white.)
            .background(Theme.navy.opacity(isEnabled ? 1 : 0.4))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
        }
        .disabled(!isEnabled || isLoading)
    }
}

struct OAuthButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(Theme.Typeface.cardMeta)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                .padding(.vertical, 13)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        // #8E8E93 at 3.26:1, not `separator` at 1.96 — this is a
                        // control boundary, which 1.4.11 wants at 3:1.
                        .stroke(Theme.fieldBorder, lineWidth: 1)
                )
        }
        .foregroundStyle(Theme.inkNavy)
    }
}

// MARK: - Fields

struct AuthField: View {
    let systemImage: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false

    @State private var reveal = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.secondaryLabel)
                .frame(width: 20)
            Group {
                if isSecure && !reveal {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .keyboardType(keyboard)
            .focused($focused)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            if isSecure {
                Button { reveal.toggle() } label: {
                    Image(systemName: reveal ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.tealTextStrong)
                        .frame(width: Theme.minTarget, height: Theme.minTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(reveal ? "Hide password" : "Show password")
            }
        }
        // Same treatment as every calculator field — 44pt, r10, 1pt #8E8E93,
        // white — established as the app-wide standard by the control inventory.
        // This carried the original invisible-field bug too: secondaryBackground
        // on a secondaryBackground page is 1.00:1.
        .frame(minHeight: Theme.minTarget)
        .padding(.horizontal, Theme.Spacing.md)
        .fieldChrome(isFocused: focused)
    }
}

struct LabeledDivider: View {
    let text: String
    var body: some View {
        HStack {
            line; Text(text).font(.caption).foregroundStyle(Theme.secondaryLabel); line
        }
    }
    private var line: some View { Rectangle().fill(Theme.separator).frame(height: 1) }
}

// MARK: - Protocol label

/// Backend protocol labels arrive DOSE-FIRST — "85mg/wk · Testosterone Enanthate".
/// Rendered as-is on one line they truncate the compound away, which is what made
/// seven dashboard cards unreadable and two identical. Every surface that shows a
/// protocol splits them here so the compound can lead, and so the two call sites
/// cannot drift apart.
enum ProtocolLabel {
    static func split(_ raw: String, fallbackDose: String = "") -> (compound: String, dose: String) {
        guard let sep = raw.range(of: " · ") else { return (raw, fallbackDose) }
        let lead = String(raw[raw.startIndex..<sep.lowerBound])
        let tail = String(raw[sep.upperBound...])
        // Whichever side carries a digit-and-unit is the dose; the other is the name.
        let leadIsDose = lead.rangeOfCharacter(from: .decimalDigits) != nil
            && tail.rangeOfCharacter(from: .decimalDigits) == nil
        return leadIsDose ? (tail, lead) : (lead, tail)
    }
}

// MARK: - Keyboard visibility

/// Publishes whether the software keyboard is on screen.
///
/// Needed because two audit findings are both "something that is fine at rest
/// becomes wrong once the keypad is up": the raised hero circle lands on the
/// primary CTA and blanks its label (F2), and the pinned result bar leaves too
/// little room for the field being edited (F11).
@MainActor
final class KeyboardObserver: ObservableObject {
    @Published private(set) var isVisible = false

    private var observers: [NSObjectProtocol] = []

    init(center: NotificationCenter = .default) {
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isVisible = true }
        })
        observers.append(center.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.isVisible = false }
        })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
}

// MARK: - Field chrome

/// Shared input surface for every calculator field, picker and stepper row.
///
/// AUDIT FINDING F5: fields used `Theme.secondaryBackground`
/// (`secondarySystemBackground`) on a page painted with `Theme.groupedBackground`
/// (`systemGroupedBackground`). In light mode both resolve to **#F2F2F7**, so the
/// boundary measured **1.00:1** against the 3:1 that WCAG 1.4.11 requires for an
/// input boundary — the field was, literally, invisible. Dark mode had hidden it,
/// and with the app now light-only it would have been permanent.
///
/// A white fill plus a hairline stroke gives the boundary real contrast, and the
/// focus ring makes the active field unambiguous.
struct FieldChrome: ViewModifier {
    var isFocused: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    // Inner shadow, applied HERE and only here so it reaches every
                    // input cell in the app at once — `fieldChrome` is the single
                    // surface for calculator fields, pickers, stepper rows and the
                    // log-dose sheet's cells. Per-screen would drift, the way the
                    // result-row identifier did.
                    //
                    // NOT MEASURED. It is styling, shipped under the build-and-move-on
                    // cadence, and nothing has been ticked on the board for it. The
                    // one thing that must be re-measured next audit is recorded in
                    // DECISIONS-2026-08-02 "Deferred checks": this shadow lands on the
                    // exact pixels of a closed finding — the input boundary was 1.00:1
                    // and was raised to `#8E8E93` at 3.26:1 — and a dark inset edge
                    // sitting against that stroke could change what that ratio means.
                    .fill(Color.white.shadow(.inner(color: .black.opacity(0.10),
                                                    radius: 3, x: 0, y: 2)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control)
                    .stroke(isFocused ? Theme.tealTextStrong : Theme.fieldBorder,
                            lineWidth: isFocused ? 2 : 1)
            )
    }
}

extension View {
    func fieldChrome(isFocused: Bool = false) -> some View {
        modifier(FieldChrome(isFocused: isFocused))
    }
}

// MARK: - Card

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            // PWA cards breathe: same content, roughly 1.6x the vertical room.
            // 16pt -> 20pt here plus the larger section spacing in DashboardScreen
            // closes most of that without a layout rewrite.
            .padding(Theme.Spacing.lg - Theme.Spacing.xs)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            // Hairline, because the card had stopped having an edge.
            //
            // T21 took the calculator's pinned plate to `.regularMaterial`, and this
            // card is `.regularMaterial` too — measured at #FEFEFE against a plate
            // measured at #FEFEFE. Two surfaces within one value of each other is not
            // a boundary, and the dose figure ended up floating on an undifferentiated
            // white field. A half-step tone difference was the other option and it is
            // disqualified by the same measurement that killed `.thinMaterial` for
            // this job: 8 values from `.bar` was rejected as a change nobody can see,
            // and this would have been smaller than that.
            //
            // One place, not per-screen. `card()` is the single card surface in the
            // app — the same reasoning as FieldChrome owning the input treatment — so
            // the dashboard's cards get the edge as well. That is deliberate and it is
            // app-wide: on #FAFAFB canvas those cards had the same weak boundary, it
            // was simply never sitting next to a second white surface where anyone
            // would notice.
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .strokeBorder(Theme.separator, lineWidth: 1 / UIScreen.main.scale)
            )
    }
}

extension View {
    /// Standard frosted card container used by dashboard + calculator result cards.
    func card() -> some View { modifier(CardBackground()) }
}

// MARK: - Loading / empty / error states (used by every networked screen)

struct LoadingView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView().tint(Theme.accent)
            Text("Loading…").font(.footnote).foregroundStyle(Theme.secondaryLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(Theme.accent.opacity(0.7))
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryLabel)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                // Caught by the CTA sweep: .borderedProminent draws white on the
                // tint, so this was white on #0FBCAD at 2.38:1 — the empty state's
                // only action, and the first button a new user ever sees.
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.navy)
                    .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(Theme.warning)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.secondaryLabel)
            // .bordered tints the LABEL, so this was #0FBCAD text at 2.38:1.
            // Secondary action, so deep teal rather than navy — 7.65:1.
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
                .tint(Theme.tealTextStrong)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// An error from an ACTION taken on an already-loaded screen — a write that failed —
/// as opposed to `ErrorBanner`, which replaces the whole screen when the LOAD failed.
///
/// This exists because the two dose-write view models had nowhere to put a failure:
/// `LoadState.failed` is the load channel, and setting it would blank a dashboard the
/// user is still reading. A write that did not happen has to say so without destroying
/// the screen it happened on, so it renders in place, above the content it concerns.
///
/// Dismissible on purpose: the user acknowledges it, they do not retry through it. The
/// retry is the control they just pressed, which is still there and still armed.
struct InlineErrorNote: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.danger)
                .accessibilityHidden(true)
            // No lineLimit: this sentence is the only thing telling a user their dose
            // was NOT recorded, and it must survive every Dynamic Type size intact.
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.label)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .frame(width: Theme.minTarget, height: Theme.minTarget)
                    .contentShape(Rectangle())
            }
            .tint(Theme.secondaryLabel)
            .accessibilityLabel("Dismiss")
        }
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .fill(Theme.danger.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.control)
                .stroke(Theme.danger.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("inline_error_note")
    }
}

/// The async load lifecycle a screen's view-model exposes; screens render off it.
enum LoadState<Value: Equatable>: Equatable {
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}

/// What a LOAD path does with a thrown error. Lives here, next to `LoadState`, because
/// this is the file anyone writing the next screen's load channel already has open.
///
/// **A CANCELLED LOAD IS NOT A FAILED LOAD.** It is the app superseding its own request
/// — a second pull-to-refresh arriving while the first is in flight, or a `.task` torn
/// down when its screen goes away. Rendering it as a failure costs the user the screen
/// they were reading for a race they did not know they caused. Measured on the
/// dashboard, twice, after a pull-to-refresh: a full-screen *"The operation couldn't be
/// completed. (Swift.CancellationError error 1.)"* **with the next-dose card gone**, on
/// an injection-dosing app's home screen.
///
/// Every load path routes its `catch` through here so the classification exists once,
/// and so the fourth view model that forgets it is visible as a difference in shape:
///
///     } catch {
///         if let message = LoadFailure.message(error) { state = .failed(message) }
///     }
///
/// **WRITE paths deliberately do NOT use this.** D9 requires a failed write to be
/// surfaced, and a cancelled write is not known to have not landed — suppressing it
/// would put a dose in exactly the "said nothing" state the optimistic-write family was
/// removed for. If a write ever needs cancellation handling it needs a different answer,
/// not this one.
enum LoadFailure {

    /// The message to render, or `nil` when the load was superseded and there is nothing
    /// to tell the user.
    static func message(_ error: Error) -> String? {
        message(error, taskWasCancelled: Task.isCancelled)
    }

    static func message(_ error: Error, taskWasCancelled: Bool) -> String? {
        guard !isCancellation(error, taskWasCancelled: taskWasCancelled) else { return nil }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    static func isCancellation(_ error: Error) -> Bool {
        isCancellation(error, taskWasCancelled: Task.isCancelled)
    }

    /// Cancellation arrives in more than one shape, and handling only one is how this
    /// comes back:
    ///
    ///   • `CancellationError` — a `Task` cancelled between suspension points. This is
    ///     the one that was measured on the dashboard.
    ///   • `URLError.cancelled` / `NSURLErrorCancelled` (-999) — URLSession's own word
    ///     for it, thrown instead when the request was already on the wire. Both the
    ///     bridged `URLError` and a raw `NSError` in `NSURLErrorDomain` are checked,
    ///     because a client library can hand back either.
    ///   • `taskWasCancelled` — the task was cancelled at all while something else
    ///     threw. A cancelled request can surface wrapped by a client library
    ///     (PostgREST/Supabase decode and transport wrappers) with neither type
    ///     surviving the wrap. On a LOAD path, suppressing that is right: either a
    ///     superseding load is already running or the screen is gone.
    ///
    /// The explicit-flag overload exists so this is testable without a live task, and so
    /// the first three checks can be exercised on their own — a classifier that only
    /// ever returns `taskWasCancelled` would look identical in a running app.
    static func isCancellation(_ error: Error, taskWasCancelled: Bool) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorCancelled { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error,
           isCancellation(underlying, taskWasCancelled: false) { return true }
        return taskWasCancelled
    }
}
