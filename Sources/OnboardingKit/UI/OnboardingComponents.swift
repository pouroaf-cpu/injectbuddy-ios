import SwiftUI

// ─── THE SHARED CONTROLS ─────────────────────────────────────────────────────
//
// Every screen in the flow is built out of the pieces in this file. Nothing here
// owns a word of copy: every string a user reads comes in from `OnboardingCopy`
// (SPEC §4 — "No string literals in views"), including the accessibility labels,
// which are read aloud and are therefore user-facing text like any other.
//
// THE RULES THIS FILE IS BUILT AGAINST
//
//   D5  — the primary action must be reachable without scrolling at every text
//         size. That is why the CTAs live in a PINNED FOOTER outside the scroll
//         view rather than at the bottom of the content: no amount of body copy
//         growth can push them off. `OnboardingScreenScaffold` is the mechanism.
//   D4  — visible truncation over silent clipping. There is no `lineLimit` in
//         this file, on a title, on a button, on a field label or anywhere else.
//         Button labels wrap and the button grows.
//   D9  *(rescued clause)* — every press gets visible feedback within 400ms.
//         `OnboardingPressStyle` is that feedback; every button here uses it.
//   DESIGN-PARITY §8 — navy #001D5C is the ACTION colour (white on it, 15.79:1);
//         teal #0FBCAD is fill-only and never text; `tealTextStrong` #075E56 is
//         the teal that is legal as text; `accentSoft` is the selected tint.
//   DESIGN-PARITY §11 — every spacing value comes from `Theme.Spacing`.

// MARK: - Entrance motion (SPEC §3.3)
//
// Owner: *"the text should feel animated and personal, not another form or buttons to
// pick."* Text ARRIVES, it does not appear: opacity 0→1 with a small upward offset,
// staggered per line, headline → body → action.
//
// **~350ms and ~60ms are not invented.** `injectbuddy-design-refs/ANIMATIONS.md` §8 lists
// `0.35s` under "Transitions / reveals"; the stagger is a delay, not a duration token.
//
// ─── ONE PASS ON ENTRY ONLY ────────────────────────────────────────────────────────
//
// Keyed on the STEP, so a back-navigation re-renders at the settled state rather than
// replaying. Re-animating on `back()` would punish the user for going back, and it would
// make the "two frames per screen, early and settled" verification meaningless.
//
// ─── REDUCE MOTION: NO OFFSET, NO STAGGER, AND NO FADE ──────────────────────────────
//
// **`ANIMATIONS.md` §9.1 says Reduce Motion KEEPS opacity changes — and that is not a
// conflict with removing the fade here.** §9.1 keeps opacity *because it carries state*:
// a control that changes colour is telling you something. **Here the opacity carries
// nothing** — it is pure entrance decoration — so removing it is the rule APPLIED, not
// broken. Written down because a later reader comparing the two documents will otherwise
// file it as a contradiction.
//
// A motion-heavy onboarding is exactly the surface that makes people ill. This is the one
// modifier in the flow that must never be "just for a moment".

/// Reveals its content on entry: fade up from a small offset, after `index × 60ms`.
struct OnboardingReveal: ViewModifier {
    let index: Int
    /// The step this reveal belongs to. Changing it re-arms the animation; that is what
    /// makes it once-per-screen rather than once-per-app.
    let step: OnboardingStep

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private static let stagger: Double = 0.06
    private static let duration: Double = 0.35
    private static let offset: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || shown ? 1 : 0)
            .offset(y: reduceMotion || shown ? 0 : Self.offset)
            .onAppear { arm() }
            // A new step re-arms. `onChange` rather than `onAppear` alone because the
            // screens share a scaffold and SwiftUI may reuse the view.
            //
            // **The iOS 16 single-parameter form, deliberately.** `project.yml` sets the
            // deployment target to **16.0**, and the two-parameter
            // `onChange(of:initial:_:)` is 17+. The compiler caught it; the point of
            // saying so here is that the newer overload will look like the obvious
            // cleanup to someone reading this on a 17+ machine.
            .onChange(of: step) { _ in
                shown = false
                arm()
            }
    }

    private func arm() {
        guard !reduceMotion else { return shown = true }
        withAnimation(.easeOut(duration: Self.duration).delay(Double(index) * Self.stagger)) {
            shown = true
        }
    }
}

extension View {
    /// `line` is the reveal order: 0 headline, 1 body, 2 action.
    func onboardingReveal(_ line: Int, step: OnboardingStep) -> some View {
        modifier(OnboardingReveal(index: line, step: step))
    }
}

// MARK: - Press feedback

/// D9's rescued clause: "every press gets visible feedback within 400ms — a
/// control that looks identical for half a second reads as broken and gets
/// pressed twice."
struct OnboardingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.62 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Progress bar

/// SPEC §3: "Progress bar percentages are part of the design, not decoration —
/// the bar **starts at 25%** on the first screen (endowed progress) and the
/// values below are exact."
///
/// Drawn as an explicit fill over an explicit track so the rendered width IS
/// `percent/100 × track width` — not a system control whose internal insets we
/// would then be measuring instead. Both parts carry an identifier so the ratio
/// can be asserted rather than eyeballed (SPEC §7), and the accessibility value
/// carries the integer percent so it can be read without a pixel at all.
struct OnboardingProgressBar: View {
    let percent: Int

    private let barHeight: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.line)
                    .accessibilityIdentifier("onboarding.progress.track")
                Capsule()
                    .fill(Theme.accent)          // fill only — never text (§8)
                    .frame(width: max(0, geo.size.width * CGFloat(percent) / 100))
                    // SPEC §3.3: ***NEVER ANIMATE THE FILL FROM ZERO ON EVERY SCREEN.***
                    // This is endowed progress — a bar that refills from empty each time
                    // is a bar that measures nothing, and it would undo the reason the
                    // 25% start exists. `nil` pins it against any ambient animation the
                    // entrance reveal or a navigation transition might otherwise donate.
                    .animation(nil, value: percent)
                    .accessibilityIdentifier("onboarding.progress.fill")
            }
        }
        .frame(height: barHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("onboarding.progress")
        .accessibilityLabel(OnboardingCopy.Accessibility.progressLabel)
        .accessibilityValue(OnboardingCopy.Accessibility.progressValue(percent))
    }
}

// MARK: - Text

/// The screen title. **No `lineLimit`, ever** — CLAUDE.md and DESIGN-PARITY §9:
/// "A long title WRAPS. It never truncates." It is also the screen's header for
/// VoiceOver.
struct OnboardingTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.largeTitle.weight(.heavy))
            .foregroundStyle(Theme.inkNavy)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("onboarding.title")
    }
}

/// The small line above a title — "Required · why we ask: …", "Optional".
struct OnboardingEyebrow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typeface.eyebrow)
            .foregroundStyle(Theme.tealTextStrong)     // 7.65:1 (§8)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("onboarding.eyebrow")
    }
}

/// Body copy. Rendered through `OnboardingCopy.attributed` so the owner's
/// **bold** survives without a view ever splitting the sentence up.
struct OnboardingBody: View {
    let text: String

    var body: some View {
        Text(OnboardingCopy.attributed(text))
            .font(.body)
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("onboarding.body")
    }
}

/// A secondary line under the body — the `.first` reassurance line (SPEC §3
/// rule 3) and the dashboard's next-dose text.
struct OnboardingSupportingLine: View {
    let text: String
    var identifier: String = "onboarding.supporting"

    var body: some View {
        Text(OnboardingCopy.attributed(text))
            .font(.callout)
            .foregroundStyle(Theme.navy)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier(identifier)
    }
}

// MARK: - Buttons

/// Primary CTA. Navy fill, white label — DESIGN-PARITY §8's action role, 15.79:1.
struct OnboardingPrimaryButton: View {
    let title: String
    var identifier: String = "onboarding.cta.primary"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)   // wraps, D4
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Theme.navy))
        }
        .buttonStyle(OnboardingPressStyle())
        .accessibilityIdentifier(identifier)
    }
}

/// Secondary CTA. White fill, navy hairline, navy label.
struct OnboardingSecondaryButton: View {
    let title: String
    var identifier: String = "onboarding.cta.secondary"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.navy)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Color.white))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.navy, lineWidth: 1.5))
        }
        .buttonStyle(OnboardingPressStyle())
        .accessibilityIdentifier(identifier)
    }
}

/// Ghost CTA — the flow's "Skip", "Skip for now", "I'll do it later", "Not now".
/// Still a full-width 44pt target; only the fill is gone.
///
/// `leading: true` is the in-content variant (setup's "＋ Add another compound"),
/// which is an action inside a form rather than one of the screen's CTAs and
/// should not out-weigh the fields it sits between.
struct OnboardingGhostButton: View {
    let title: String
    var identifier: String = "onboarding.cta.ghost"
    var leading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.navy)
                .multilineTextAlignment(leading ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity,
                       minHeight: Theme.minTarget,
                       alignment: leading ? .leading : .center)
                .contentShape(Rectangle())          // the whole row is the target
                .padding(.horizontal, leading ? 0 : Theme.Spacing.md)
        }
        .buttonStyle(OnboardingPressStyle())
        .accessibilityIdentifier(identifier)
    }
}

/// A tappable option on a branch screen (`pathway`, `experience`). The option IS
/// the primary action on those screens — there is no separate CTA — so these are
/// what D5 is about there.
/// SPEC §3.3: *"The choice screens stop being button stacks."* Full-width cards with room
/// to breathe — label, one supporting line where the copy gives one, generous vertical
/// padding. **They should read as choosing a lane, not as a form control.**
///
/// **Selected state is a FILL, not a checkmark**, per the brief. The chevron is gone: it
/// promised navigation on a control that commits a choice.
///
/// **Every spacing value is from `Theme.Spacing`** (`DESIGN-PARITY` §11, the
/// `4 · 8 · 16 · 24 · 32` grid). "Generous vertical padding" is `lg` = 24 — **on the
/// scale, so it is not a finding.** Verified against `Theme.swift`: nothing here needed a
/// value the token scale does not have.
struct OnboardingChoiceRow: View {
    let title: String
    /// One supporting line, only where the copy gives one. `nil` on screens whose options
    /// are bare labels — this control does not invent a subtitle to fill the space.
    var subtitle: String? = nil
    var isSelected: Bool = false
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? Theme.tealTextStrong : Theme.inkNavy)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.navy)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.lg)      // room to breathe — on the scale
            .frame(maxWidth: .infinity, minHeight: Theme.minTarget, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    // THE SELECTED STATE, AND IT IS A FILL. `accentSoft` is the selected
                    // tint (DESIGN-PARITY §8); teal is fill-only and never text, which is
                    // why the label above uses `tealTextStrong` and not `accent`.
                    .fill(isSelected ? Theme.accentSoft : Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? Theme.tealTextStrong : Theme.line,
                                  lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(OnboardingPressStyle())
        .accessibilityIdentifier(identifier)
        // The fill carries the state visually; this is the same state in the tree, for
        // anyone who cannot see a fill. Colour is reinforcement, never the only channel.
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Placeholder copy

/// **A PLACEHOLDER FOR A LINE THE OWNER HAS NOT WRITTEN. MUST NOT SHIP.**
///
/// Drawn like `OnboardingIllustrationPlaceholder` — warning-coloured, dashed — because it
/// is the same kind of hole. A missing sentence rendered in ordinary type reads as
/// finished copy; a later reader would have no way to tell it from the owner's writing,
/// which is exactly what the instruction to keep it visibly a placeholder is about.
struct OnboardingPlaceholderLine: View {
    let text: String

    private static let warningLabel = "PLACEHOLDER — NOT OWNER COPY, NOT FOR SHIP"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(Self.warningLabel)
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.warning)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.warning.opacity(0.08)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.warning,
                              style: StrokeStyle(lineWidth: 2, dash: [8, 6])))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.placeholder.copy")
    }
}

// MARK: - Fields

/// Screen 1's name field. SPEC §3.1.
///
/// **`maxLength` is enforced HERE, at the keyboard**, not discovered at a sink: the server
/// rejects a nickname over 60 characters with a 400, and the last possible moment is the
/// worst place to find that out.
///
/// **No `lineLimit` on the label or the note** — and the name itself lands in a screen
/// title downstream, where the ban applies (`CLAUDE.md`, `DESIGN-PARITY` §9): a long name
/// wraps, it does not truncate.
struct OnboardingNameField: View {
    let label: String
    let optionalNote: String
    let placeholder: String
    let maxLength: Int
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(label)
                    .font(Theme.Typeface.cardMeta)
                    .foregroundStyle(Theme.navy)
                    .fixedSize(horizontal: false, vertical: true)
                Text(optionalNote)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(placeholder, text: $text)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .textContentType(.nickname)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused(isFocused)
                .onSubmit(onSubmit)
                // iOS 16 single-parameter form — see the note on `OnboardingReveal`.
                .onChange(of: text) { new in
                    if new.count > maxLength { text = String(new.prefix(maxLength)) }
                }
                .padding(Theme.Spacing.sm)
                .frame(minHeight: Theme.minTarget)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Color.white))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.fieldBorder, lineWidth: 1))
                .accessibilityLabel(label)
                .accessibilityIdentifier("onboarding.welcome.name")
        }
    }
}

/// A labelled text entry. The border is `Theme.fieldBorder` — 3.26:1, the token
/// that exists precisely so a field boundary satisfies WCAG 1.4.11, where
/// `Theme.line` does not.
struct OnboardingField: View {
    let label: String
    @Binding var value: String
    var keyboard: UIKeyboardType = .default
    var identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: $value)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(Theme.Spacing.sm)
                .frame(minHeight: Theme.minTarget)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Color.white))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .strokeBorder(Theme.fieldBorder, lineWidth: 1))
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
        }
    }
}

/// The units picker. A wrapping grid rather than a `Picker(.segmented)` on
/// purpose: a segmented control compresses its labels to fit and at large text
/// "units" would shear — which is exactly the failure D4 is about. An adaptive
/// grid re-flows onto more rows instead, so nothing is ever cut.
struct OnboardingUnitPicker: View {
    let label: String
    @Binding var selection: OnboardingUnitPreference?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Typeface.cardMeta)
                .foregroundStyle(Theme.navy)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 84), spacing: Theme.Spacing.sm)],
                alignment: .leading,
                spacing: Theme.Spacing.sm
            ) {
                ForEach(OnboardingUnitPreference.allCases, id: \.self) { unit in
                    let isSelected = selection == unit
                    Button {
                        selection = unit
                    } label: {
                        Text(OnboardingCopy.Setup.unit(unit))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Theme.tealTextStrong : Theme.navy)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .fill(isSelected ? Theme.accentSoft : Color.white))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Theme.tealTextStrong : Theme.fieldBorder,
                                        lineWidth: isSelected ? 2 : 1))
                    }
                    .buttonStyle(OnboardingPressStyle())
                    .accessibilityIdentifier("onboarding.setup.unit.\(unit.rawValue)")
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
        }
    }
}

// MARK: - Cards

/// A plain content card — the founder note, the timeline, the split rows.
struct OnboardingCard<Content: View>: View {
    var identifier: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Color.white))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1))
        .accessibilityIdentifier(identifier ?? "onboarding.card")
    }
}

/// **A MOCK OF REAL UI — NOT AN ILLUSTRATION.**
///
/// SPEC §5: "The `dashboard` end state's three placeholders are NOT part of the
/// fifteen and must never reach the art list. Active levels chart, next dose
/// card and cycle plotter pre-loaded are MOCKS OF REAL UI, not illustrations to
/// commission."
///
/// It is drawn deliberately UNLIKE `OnboardingIllustrationPlaceholder` — neutral,
/// not warning-coloured — so that a screenshot of the dashboard can never be
/// mistaken for one carrying three more pieces of missing art.
struct OnboardingUIMock<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content

    init(label: String, @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(OnboardingCopy.Debug.uiMock)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
            Text(label)
                .font(Theme.Typeface.cardTitle)
                .foregroundStyle(Theme.inkNavy)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(Theme.surface))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
    }
}

// MARK: - The screen scaffold

/// Header + scrolling content + **pinned footer**.
///
/// D5 is the whole reason for the shape: the actions sit in the footer, outside
/// the `ScrollView`, so the primary action is on screen at every text size no
/// matter how far the body copy grows. The screens that have no separate CTA
/// (`pathway`, `experience` — where the options are the action) pass
/// `showsFooter: false` and get no empty bar.
struct OnboardingScreenScaffold<Content: View, Actions: View>: View {
    @ObservedObject var flow: OnboardingFlow
    var showsFooter: Bool = true
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.lg)
            }
            if showsFooter {
                footer
            }
        }
        .background(Theme.canvas.ignoresSafeArea())
    }

    // Back + the debug restart, then the bar. SPEC §3: "Back must work from
    // every screen"; the restart is a debug affordance only and is drawn as one.
    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.md) {
                if flow.canGoBack {
                    Button {
                        flow.back()
                    } label: {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "chevron.left")
                                .accessibilityHidden(true)      // D3 — decorative
                            Text(OnboardingCopy.Navigation.back)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.navy)
                        .frame(minWidth: Theme.minTarget, minHeight: Theme.minTarget,
                               alignment: .leading)
                    }
                    .buttonStyle(OnboardingPressStyle())
                    .accessibilityIdentifier("onboarding.back")
                } else {
                    // Holds the row's height so the bar does not jump between
                    // screen 1 and screen 2. D2 — clearance where a thing is pinned.
                    Color.clear.frame(width: 1, height: Theme.minTarget)
                }
                Spacer(minLength: Theme.Spacing.sm)
                Button {
                    flow.restart()
                } label: {
                    Text(OnboardingCopy.Debug.restart)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .frame(minHeight: Theme.minTarget)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(OnboardingPressStyle())
                .accessibilityIdentifier("onboarding.restart")
            }

            // SPEC §3 — exact percentages. `nil` on the two end states, which
            // carry no bar at all.
            if let percent = flow.barPercent {
                OnboardingProgressBar(percent: percent)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.sm)
    }

    /// **`fixedSize` AND `layoutPriority` ARE THE DEFECT FIX, NOT TIDYING.**
    ///
    /// Measured at AX5 on the paywall (three stacked CTAs), 2026-08-03: without
    /// them the `VStack` handed the footer LESS than its ideal height, the button
    /// labels — which are `fixedSize` and will not compress — drew straight out
    /// of their own backgrounds, and all three CTAs plus the body copy rendered
    /// on top of each other, illegible. That is worse than truncation: D4 is
    /// about a user not seeing some characters; this was a user seeing three
    /// strings at once.
    ///
    /// With them, the footer takes the height it needs and the scroll view takes
    /// the remainder — so the actions stay legible and reachable at every text
    /// size, which is what D5 is actually asking for.
    private var footer: some View {
        VStack(spacing: Theme.Spacing.sm) {
            actions()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .layoutPriority(1)
        .background(Theme.canvas)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }
}
