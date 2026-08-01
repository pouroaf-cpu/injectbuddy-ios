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
            // #075E56, not #0FBCAD. Contrast is symmetric — white on #0FBCAD is
            // the same 2.38:1 as #0FBCAD text on white, so "make it a filled teal
            // button" does not fix the contrast failure on its own. White on
            // #075E56 is 7.65:1 and clears AAA, and it leaves #0FBCAD for the FAB
            // and large display type per DESIGN-PARITY §7.
            .background(Theme.tealTextStrong.opacity(isEnabled ? 1 : 0.4))
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
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control)
                        .stroke(Theme.separator, lineWidth: 1)
                )
        }
        .foregroundStyle(Theme.label)
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
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            if isSecure {
                Button { reveal.toggle() } label: {
                    Image(systemName: reveal ? "eye.slash" : "eye")
                        .foregroundStyle(Theme.secondaryLabel)
                }
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control))
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
                    .fill(Color.white)
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
            .padding(Theme.Spacing.md)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
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
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
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
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
                .tint(Theme.accent)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The async load lifecycle a screen's view-model exposes; screens render off it.
enum LoadState<Value: Equatable>: Equatable {
    case loading
    case loaded(Value)
    case empty
    case failed(String)
}
