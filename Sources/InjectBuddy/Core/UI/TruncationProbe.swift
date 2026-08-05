import SwiftUI

// ─── TruncationProbe ─────────────────────────────────────────────────────────
// T19. DEBUG-only. Publishes, per labelled view, whether it is RENDERING NARROWER
// THAN IT NEEDS TO BE — i.e. whether it truncated.
//
// WHY THIS EXISTS, stated so a future green run is not over-read.
//
// The truncation sweep that shipped (T4b) asserts a geometric invariant: a value
// cell is never narrower than its own unit. It replaced a textual assertion that
// COULD NOT FAIL — "the displayed string contains no ellipsis" reads the
// accessibility layer, which returns model text, and passes on the exact frame
// rendering `1…` (measured: `field.value == "100"`).
//
// The geometric version is real and it goes red on all three mechanisms that have
// produced this bug. But it is a RATIO, and its blind spot is documented and
// reachable rather than theoretical: A LONG VALUE BESIDE A SHORT UNIT. `1000`
// truncated to `10…` next to `mg` keeps the ratio and passes green.
// `Reconstitution.targetConc` holds 1000 in a 49.7pt cell, so four-digit doses are
// ORDINARY in this app.
//
// HOW THIS OBSERVES THE RIGHT LAYER. §5.23 asks which layer actually observes the
// thing being asserted. Truncation is a fact about LAYOUT, so the measurement is
// taken from layout: the same view is laid out twice, once as it really renders and
// once free of any width constraint, and the two resolved widths are compared. The
// renderer computes both numbers. Nothing here reconstructs a UIFont, guesses at a
// resolved text style, or re-implements Dynamic Type — all of which would be a
// second opinion about the thing rather than the thing.
//
// The unconstrained copy carries `.fixedSize(horizontal: true, vertical: false)` and
// that is the whole trick, for the same reason it was load-bearing on the pinning
// gate (§5.25): a `.background` is proposed the size of the view it decorates, so
// without it the "ideal" copy would be squeezed to exactly the width being tested
// and the probe would report `false` on every truncation in the app — a check that
// cannot fail, added to close a check that could not fail.
//
// Degrades to nothing in Release: the modifier returns `content` untouched.

extension View {
    /// Publishes `trunc_<id>` = "true"/"false" for a text view, DEBUG only.
    func truncationProbe(_ id: String) -> some View {
        modifier(TruncationProbe(id: id))
    }
}

struct TruncationProbe: ViewModifier {
    let id: String

    func body(content: Content) -> some View {
        #if DEBUG
        content
            .background { widthReader(TruncationWidths.renderedKey) }
            // The same view, laid out with no width constraint, hidden. Alignment is
            // leading so the overflow runs off one side rather than being centred and
            // clipped symmetrically — irrelevant to the number, but it keeps the hidden
            // copy from wandering under anything during layout debugging.
            .background(alignment: .leading) {
                content
                    .fixedSize(horizontal: true, vertical: false)
                    .hidden()
                    .allowsHitTesting(false)
                    // `.hidden()` leaves an element in the ACCESSIBILITY TREE (§5.6),
                    // and this copy contains the same dose string as the real one. A
                    // VoiceOver user meeting every value twice — once from a
                    // measurement artefact — is a defect introduced by the tool
                    // checking for defects.
                    .accessibilityHidden(true)
                    .background { widthReader(TruncationWidths.idealKey) }
            }
            .overlayPreferenceValue(TruncationWidths.self) { widths in
                probe(widths)
            }
        #else
        content
        #endif
    }

    #if DEBUG
    private func widthReader(_ key: String) -> some View {
        GeometryReader { g in
            Color.clear.preference(key: TruncationWidths.self, value: [key: g.size.width])
        }
    }

    /// Zero-sized element carrying the verdict AND both widths. The widths are
    /// published too because "truncated" with no numbers is a failure message nobody
    /// can act on — the first question is always "by how much".
    @ViewBuilder
    private func probe(_ widths: [String: CGFloat]) -> some View {
        let rendered = widths[TruncationWidths.renderedKey] ?? 0
        let ideal = widths[TruncationWidths.idealKey] ?? 0
        // Half a point of slack for sub-pixel rounding. Truncation costs an ellipsis,
        // which is several points wide at any size, so this cannot mask a real one.
        let truncated = ideal > rendered + 0.5 && rendered > 0
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityElement()
            .accessibilityIdentifier("trunc_\(id)")
            .accessibilityLabel(truncated ? "true" : "false")
            .accessibilityValue(String(format: "rendered=%.2f ideal=%.2f", rendered, ideal))
    }
    #endif
}

/// Widths for ONE probed view. Scoped by `overlayPreferenceValue` reading only its own
/// subtree, so two probes on one screen cannot read each other's numbers.
struct TruncationWidths: PreferenceKey {
    static let renderedKey = "rendered"
    static let idealKey = "ideal"
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { max($0, $1) }
    }
}
