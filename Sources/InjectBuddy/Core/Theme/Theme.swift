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
    // Every face is built with `relativeTo:` so it still scales with Dynamic Type.

    enum Typeface {
        /// Greeting — PWA 24px / 800 / -0.03em.
        static let greeting = Font.system(size: 24, weight: .heavy, design: .default)
        static let greetingTracking: CGFloat = -0.72   // -0.03em × 24pt

        /// Display numeral — the primary metric on a card. Tabular by convention;
        /// apply `.monospacedDigit()` at the call site.
        static let display = Font.system(size: 34, weight: .heavy, design: .default)
        static let displayTracking: CGFloat = -1.02

        /// Section eyebrow — "TODAY", "PROTOCOLS".
        static let eyebrow = Font.system(size: 13.5, weight: .semibold)

        /// Card title.
        static let cardTitle = Font.system(size: 17, weight: .bold)
        /// Card supporting line.
        static let cardMeta = Font.system(size: 14, weight: .medium)

        /// Tab bar label — 13.5px / 600, 700 when active.
        static let tabLabel = Font.system(size: 13.5, weight: .semibold)
        static let tabLabelActive = Font.system(size: 13.5, weight: .bold)

        /// Value + unit pairs inside result rows.
        static let resultValue = Font.system(size: 22, weight: .bold)
        static let resultLabel = Font.system(size: 15, weight: .medium)
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
