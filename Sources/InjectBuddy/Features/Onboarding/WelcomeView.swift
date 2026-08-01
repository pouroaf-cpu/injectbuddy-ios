import SwiftUI

// ─── WelcomeView ─────────────────────────────────────────────────────────────
// The first screen. Occupies `.loading` while the persisted session resolves, and
// fronts `.signedOut` as the entry point.
//
// THE BEHAVIOUR THAT OUTRANKS THE ANIMATION: a returning signed-in user must never
// wait on it. RootView switches on `AuthStore.Phase`, so if the session resolves in
// 200ms this screen is gone in 200ms — the animation duration is a CEILING on how
// long it MAY remain, never a floor. Nothing here blocks, sleeps, or gates the
// phase change. A daily-use dosing app is the wrong place to spend someone's time
// on branding.
//
// Signed-out users get the full sequence, because for them it is the entry point
// rather than an interruption.

struct WelcomeView: View {
    /// Nil in `.loading` — the CTAs only exist once we know there's no session.
    var onCreateAccount: (() -> Void)?
    var onSignIn: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var showsCTAs: Bool { onCreateAccount != nil }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            SerumCurveField().ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                SyringeMark(progress: reduceMotion || appeared ? 1 : 0)
                    .frame(width: 92, height: 92)
                    .padding(.bottom, Theme.Spacing.lg)

                // Solid fills throughout. A multi-stop gradient on text renders
                // desaturated in SwiftUI regardless of stop spacing — measured, and
                // the reason the dashboard greeting ships solid. See BOARD §3.
                rise(index: 0) {
                    HStack(spacing: 6) {
                        Text("inject").foregroundColor(Theme.tealTextStrong)
                        + Text("buddy").foregroundColor(Theme.tealTextStrong).bold()
                    }
                    .font(.system(size: 34, weight: .heavy))
                    .tracking(-1.0)
                }

                rise(index: 1) {
                    Text("Plan the cycle. Log the dose. Know the day.")
                        .font(Theme.Typeface.cardMeta)
                        .foregroundStyle(Theme.navy)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Spacing.sm)
                        .padding(.horizontal, Theme.Spacing.xl)
                }

                Spacer(minLength: 0)

                if showsCTAs {
                    rise(index: 2) {
                        VStack(spacing: Theme.Spacing.sm) {
                            PrimaryButton(title: "Create account") { onCreateAccount?() }
                            Button { onSignIn?() } label: {
                                Text("Sign in")
                                    .font(.headline)
                                    .foregroundStyle(Theme.navy)
                                    .frame(maxWidth: .infinity, minHeight: Theme.minTarget)
                                    .padding(.vertical, 14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.control)
                                            .stroke(Theme.navy, lineWidth: 1.5)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                } else {
                    // .loading — a quiet indicator, no CTAs to press yet.
                    ProgressView()
                        .tint(Theme.tealTextStrong)
                        .padding(.bottom, Theme.Spacing.xl * 2)
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        }
    }

    /// Staggered fade + rise — ~60ms apart, 450ms each, ease-out. Restraint reads
    /// as professional; bounce and spring read as consumer-toy. Under Reduce Motion
    /// the final state is applied immediately with no transition at all.
    @ViewBuilder
    private func rise<Content: View>(index: Int, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .opacity(reduceMotion || appeared ? 1 : 0)
            .offset(y: reduceMotion || appeared ? 0 : 12)
            .animation(reduceMotion ? nil
                       : .easeOut(duration: 0.45).delay(Double(index) * 0.06),
                       value: appeared)
    }
}

// MARK: - Serum curves

/// Drifting serum-concentration curves — the rise-and-decay shape the PWA's
/// SerumChart draws for real. Chosen over particles or constellation lines because
/// it means something specific to this product: anyone who has looked at a dose
/// curve recognises it, and everyone else reads calm motion.
///
/// One `Canvas` inside `TimelineView(.animation)`: a single redraw surface with no
/// view-tree churn, and it stops when the screen goes away.
///
/// **Opacity is capped and the curves are held to the lower half.** A background
/// that drops body text under 4.5:1 is a failure however good it looks — that rule
/// outranks the aesthetics, and both competitor reference sets ship exactly this
/// failure mid-transition.
private struct SerumCurveField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let curves: [(amplitude: Double, phase: Double, speed: Double, opacity: Double)] = [
        (0.42, 0.00, 0.055, 0.16),
        (0.30, 1.10, 0.038, 0.11),
        (0.22, 2.40, 0.027, 0.08),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let t = reduceMotion ? 0
                    : timeline.date.timeIntervalSinceReferenceDate
                for curve in Self.curves {
                    context.stroke(
                        path(in: size, curve: curve, time: t),
                        with: .color(Theme.accent.opacity(curve.opacity)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                }
            }
            .accessibilityHidden(true)
        }
    }

    /// A one-compartment rise-and-decay: fast absorption, slow elimination —
    /// the same shape a real concentration curve has.
    private func path(in size: CGSize,
                      curve: (amplitude: Double, phase: Double, speed: Double, opacity: Double),
                      time: Double) -> Path {
        var p = Path()
        // Held to the lower 45% of the screen so the curves never cross the
        // wordmark or the supporting line above them.
        let baseline = size.height * 0.97
        let span = size.height * 0.45
        let drift = time * curve.speed + curve.phase
        let steps = 96

        for step in 0...steps {
            let x = Double(step) / Double(steps)
            // Re-phasing: the curve slides and its peak breathes slightly, so two
            // passes never look identical without anything jumping.
            let u = (x + drift).truncatingRemainder(dividingBy: 1.0)
            let rise = 1 - exp(-u * 7)
            let decay = exp(-u * 2.2)
            let y = rise * decay * curve.amplitude * (1 + 0.12 * sin(drift * 1.7))
            let point = CGPoint(x: x * size.width, y: baseline - y * span)
            step == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        return p
    }
}

// MARK: - Syringe mark

/// The mark draws itself with `Path.trim` — the canonical SwiftUI line-draw, and
/// cheap. Stroke while drawing, never fill.
private struct SyringeMark: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.accentSoft)
            Image(systemName: "syringe.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.navy)
                .opacity(progress)
                .scaleEffect(0.85 + 0.15 * progress)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeOut(duration: 0.7), value: progress)
        .accessibilityHidden(true)
    }
}
