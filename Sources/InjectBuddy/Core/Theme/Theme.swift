import SwiftUI

// ─── Theme ───────────────────────────────────────────────────────────────────
// Brand tokens shared with the PWA. Values and their PWA source files are
// recorded in docs/DESIGN-PARITY.md — cite that file, don't invent hexes here.
//
// The old header of this file said to mirror the web "without forcing exact
// hexes — system materials read better natively". That instruction is why the
// two dashboards diverged, and it is revoked for BRAND COLOUR and TYPOGRAPHY.
// It still stands for PLATFORM BEHAVIOUR: sheets, blur materials, haptics,
// scroll physics, nav transitions and the Dynamic Type / accessibility stack
// stay native. We match the brand, not the web layout engine.
//
// The app is LIGHT ONLY (locked by UIUserInterfaceStyle in project.yml). The
// remaining semantic colours below therefore resolve to their light values
// permanently and deterministically; they are kept where no brand equivalent
// exists rather than churned out for their own sake.

enum Theme {

    // MARK: - Brand palette

    /// Primary accent. FILL ONLY — never a text colour. #0FBCAD on white is
    /// 2.38:1 and fails WCAG at every size, including the 3:1 large-text floor.
    /// For teal text use `tealText` (3.37:1) or `tealTextStrong` (7.65:1).
    static let accent = Color(hex: 0x0FBCAD)
    /// Selected-state / tint fill.
    static let accentSoft = Color(hex: 0xEAFAF8)
    /// Alternate tint.
    static let accentSoft2 = Color(hex: 0xF0FBFA)

    /// Second brand colour — icon buttons, section labels, dose numerals.
    /// 15.13:1 on `canvas`.
    static let navy = Color(hex: 0x001D5C)
    /// Heading ink where full navy is too saturated.
    static let inkNavy = Color(hex: 0x111A3A)
    /// Body ink.
    static let ink = Color(hex: 0x101018)

    /// Teal that is legal as text. 7.65:1 on white — clears the 7:1 target.
    static let tealTextStrong = Color(hex: 0x075E56)
    /// Lighter teal text / greeting gradient base. 3.37:1 on white, so it is
    /// only legal for large text (18pt+ regular, 14pt+ bold).
    static let tealText = Color(hex: 0x0A9D90)
    // REMOVED: tealShimmer #5FE8DA. The PWA uses it as the greeting gradient's
    // highlight stop, but it measures 1.50:1 on white — and at the sweep's
    // midpoint that stop IS the text colour, so the greeting became the
    // lowest-contrast text on the dashboard while being the largest type on it.
    // The shimmer is now cut from legal stops only (#075E56 -> #0A9D90 ->
    // #075E56); the highlight still reads because the eye tracks the luminance
    // change, not the absolute value.

    /// Page canvas.
    static let canvas = Color(hex: 0xFAFAFB)
    /// Raised tile fill.
    static let surface = Color(hex: 0xF8F8FB)
    /// Hairline rule for decorative separation (card edges, dividers). Decorative
    /// rules are exempt from 1.4.11, which is why this may stay this light.
    static let line = Color.black.opacity(0.12)
    /// Border for INPUT boundaries specifically. 3.26:1 on white, so it satisfies
    /// WCAG 1.4.11's 3:1 for identifying a control. `line` measured only ~1.3:1
    /// over the canvas — visible, but not enough to be the thing that identifies a
    /// field, which is exactly what it is on this form.
    static let fieldBorder = Color(hex: 0x8E8E93)

    // MARK: - Calculator parity tokens (T-01a)
    //
    // SAMPLED PER-PIXEL from `injectbuddy-design-refs/screens/30-calc-trt-result.png`,
    // not read out of the CSS cascade and not eyeballed. The frame is 1170x4227; the
    // coordinate each value came from is on the line, so the next person re-measures
    // rather than re-derives. Two of them landed on tokens this file already had —
    // the page canvas sampled #FAFAFB, exactly `canvas` — which is the check that the
    // sampling is reading what it thinks it is reading.

    /// The result bar's fill. (300,2505) → #00FFEE. The web's sticky `Show result`
    /// bar is full-bleed BRIGHT CYAN and it is unmistakably the primary action.
    ///
    /// FILL ONLY, and more so than `accent`: #00FFEE is 1.35:1 against white. The
    /// label on it is `navy`, which measures 12.7:1 — the reference frame draws it
    /// dark for the same reason.
    static let ctaCyan = Color(hex: 0x00FFEE)

    /// A calculator field ROW's fill. (70,545) → #F1F1F4, uniform across the row.
    ///
    /// The web's numeric row is one flat grey group holding label, value and ruler,
    /// which is what makes it read as a single control. Note what the sampling
    /// SETTLED: T-01a #8 describes the label as sitting "in a grey pill"; the pill
    /// and the row measure the same #F1F1F4, so the pill is not a separate fill. The
    /// placement half of #8 (label left, same row) is right; the pill half is not.
    static let fieldRowFill = Color(hex: 0xF1F1F4)

    /// The value well inside a field row. (560,545) → #E6E6E9 — DARKER than the row
    /// it sits in, i.e. a recessed well rather than a raised white box.
    static let valueWell = Color(hex: 0xE6E6E9)

    /// The value well's border. (520,545) → #243C73. This is the "heavy navy-outlined
    /// box" of T-01a #9 and it is what makes the number the focus of the row.
    static let valueWellBorder = Color(hex: 0x243C73)

    /// The mode switcher's recessed track. (700,248) → #E6E6EE. The active pill is
    /// #FFFFFF, sampled at (210,248).
    static let modeTrack = Color(hex: 0xE6E6EE)

    /// The plotter link's tint. (300,1370) → #E4F3F3. Deliberately NOT `accentSoft`
    /// (#EAFAF8): they are close and they are not the same, and this file's whole
    /// premise is that "close enough" is how the two apps drifted.
    static let plotTint = Color(hex: 0xE4F3F3)

    /// The formula card's inner well. (200,3450) → #F5F5F5, inside a #FFFFFF card.
    static let formulaWell = Color(hex: 0xF5F5F5)

    // MARK: - Semantic (kept where no brand token exists)

    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let separator = Color(.separator)

    /// 7.90:1 on white. The previous #FF5757 measured 3.11:1 and failed as body text.
    static let danger = Color(hex: 0xA31313)
    static let warning = Color(hex: 0xB45309)
    static let success = Color(hex: 0x0F7A5F)

    // MARK: - Typography
    //
    // The PWA is Inter throughout. We ship SF with matched weights and tracking
    // rather than bundling Inter: SF keeps the Dynamic Type metrics and optical
    // sizing that stop values truncating at accessibility sizes, which is the
    // highest-severity open finding. Revisit once that is closed.
    //
    // ── THE TOKENS SCALE. THEY DID NOT UNTIL 2026-08-02. ────────────────────────
    //
    // The line that used to sit here read "Every face is built with `relativeTo:`
    // so it still scales with Dynamic Type." Not one of them was. Every token was
    // `Font.system(size:weight:design:)` — a FIXED point size, which SwiftUI does
    // not apply Dynamic Type to. Only text styles scale.
    //
    // Measured rather than reasoned: the dashboard at default (`IB2245723`) and at
    // AX5 (`IB2245730`) render the greeting and the `PROTOCOLS` eyebrow at
    // pixel-identical size, while everything on the same screen still using system
    // text styles — "Next dose", the protocol title, "due today", "Mark taken" —
    // scales enormously. The screen does not merely fail to grow: the hierarchy
    // INVERTS. The greeting is the largest text on the screen at default size and
    // one of the smallest at AX5.
    //
    // This mattered more than it looks, because the queued work was "apply the type
    // scale to the ten screens that don't have it" — and nine of those ten have no
    // `Theme.Typeface` at all, meaning they use system text styles and scale
    // CORRECTLY today. That sweep would have replaced working Dynamic Type with
    // frozen sizes on ten screens, starting with `DisclaimerGate`, the first screen
    // a new user sees.
    //
    // Every token is now a text style plus an explicit weight, so it tracks Dynamic
    // Type. Most map exactly (display 34 = .largeTitle, cardTitle 17 = .headline,
    // resultValue 22 = .title2, resultLabel 15 = .subheadline). Two move by ~2pt at
    // default size — greeting 24 -> 22 and cardMeta 14 -> 15 — which is the price of
    // the whole scale scaling, and it is cheap.
    //
    // RULE: nothing in here may go back to `Font.system(size:)`. A fixed size in a
    // shared token is invisible at the call site and silently opts that text out of
    // Dynamic Type. If a design needs a size the text styles do not offer, scale it
    // with `@ScaledMetric` at the call site rather than freezing it here.

    enum Typeface {
        /// Greeting — PWA 24px / 800 / -0.03em. `.title2` is 22pt at Large.
        static let greeting = Font.system(.title2, design: .default, weight: .heavy)
        /// Absolute, so it does not grow with the face. Negligible once the text is
        /// large; it exists to tighten the default-size rendering.
        static let greetingTracking: CGFloat = -0.72

        /// Display numeral — the primary metric on a card. `.largeTitle` is 34pt at
        /// Large, matching the PWA exactly. Tabular by convention; apply
        /// `.monospacedDigit()` at the call site.
        static let display = Font.system(.largeTitle, design: .default, weight: .heavy)
        static let displayTracking: CGFloat = -1.02

        /// Section eyebrow — "TODAY", "PROTOCOLS". 13pt at Large.
        static let eyebrow = Font.system(.footnote, weight: .semibold)

        /// Card title. 17pt at Large, exactly as before.
        static let cardTitle = Font.system(.headline, weight: .bold)
        /// Card supporting line. 15pt at Large, was a frozen 14.
        static let cardMeta = Font.system(.subheadline, weight: .medium)

        /// Tab bar label. 12pt at Large, was a frozen 13.5.
        static let tabLabel = Font.system(.caption, weight: .semibold)
        static let tabLabelActive = Font.system(.caption, weight: .bold)

        /// Value + unit pairs inside result rows. 22pt and 15pt at Large, both
        /// unchanged from the frozen sizes they replace.
        static let resultValue = Font.system(.title2, weight: .bold)
        static let resultLabel = Font.system(.subheadline, weight: .medium)
    }

    // MARK: - Spacing / radius

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 10
        static let pill: CGFloat = 999
    }

    /// Minimum comfortable hit target. HIG floor is 44×44 pt.
    static let minTarget: CGFloat = 44

    // MARK: - sRGB-interpolated gradients
    //
    // SwiftUI interpolates gradient stops in a linear-light space, which desaturates
    // dark saturated colours badly. Measured on this palette: a two-stop ramp between
    // #075E56 and #0A9D90 rendered #4B5557 -> #798A8D -> #4B5557 — right shape, no
    // chroma — while a gradient whose two stops were IDENTICAL rendered #075E56
    // exactly. The lift lands hardest on the darkest channel: red goes 7 -> 75 while
    // green and blue barely move.
    //
    // `LinearGradient` exposes no colour-space control in the iOS 18.2 SDK (only
    // `MeshGradient` takes a `Gradient.ColorSpace`), so the fix is to do the blending
    // ourselves: interpolate in sRGB here and hand the gradient many closely-spaced
    // stops, leaving each segment a range too small to drift measurably.

    /// Stops interpolated in sRGB between the given 0xRRGGBB anchors.
    static func srgbStops(_ anchors: [UInt32], perSegment: Int = 12) -> [Gradient.Stop] {
        guard anchors.count > 1 else {
            return anchors.map { Gradient.Stop(color: Color(hex: $0), location: 0) }
        }
        func channels(_ hex: UInt32) -> (Double, Double, Double) {
            (Double((hex >> 16) & 0xFF), Double((hex >> 8) & 0xFF), Double(hex & 0xFF))
        }
        var stops: [Gradient.Stop] = []
        let segments = anchors.count - 1
        for segment in 0..<segments {
            let from = channels(anchors[segment])
            let to = channels(anchors[segment + 1])
            // The last sub-step of a segment is the next segment's first, so drop it
            // except on the final segment — otherwise stops land on top of each other.
            let upper = segment == segments - 1 ? perSegment : perSegment - 1
            for step in 0...upper {
                let t = Double(step) / Double(perSegment)
                let location = (Double(segment) + t) / Double(segments)
                stops.append(Gradient.Stop(
                    color: Color(.sRGB,
                                 red: (from.0 + (to.0 - from.0) * t) / 255,
                                 green: (from.1 + (to.1 - from.1) * t) / 255,
                                 blue: (from.2 + (to.2 - from.2) * t) / 255),
                    location: location))
            }
        }
        return stops
    }

    /// Greeting sweep. Every anchor is legal on its own — #075E56 is 7.65:1 and
    /// #0A9D90 is 3.37:1 — so no phase of the animation can drop the text below the
    /// 3:1 large-text floor.
    static let greetingStops = srgbStops([0x075E56, 0x0A9D90, 0x075E56])

    /// Drawer open/close animation — matches the web drawer feel (~0.26s spring).
    static let drawerAnimation: Animation = .spring(response: 0.26, dampingFraction: 0.86)
}

// MARK: - Color(hex:)

extension Color {
    /// Build a Color from a 0xRRGGBB literal.
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
