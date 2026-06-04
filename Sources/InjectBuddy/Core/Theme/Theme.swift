import SwiftUI

// ─── Theme ───────────────────────────────────────────────────────────────────
// Teal #0fbcad accent, light/dark aware. Mirrors the web look (Inter-ish system
// font, frosted cards) without forcing exact hexes — system materials read better
// natively. All screens pull colors/spacing from here; never hard-code hexes in views.

enum Theme {
    /// Brand teal — the single accent used across the app.
    static let accent = Color(hex: 0x0FBCAD)
    static let accentSoft = Color(hex: 0x0FBCAD).opacity(0.14)

    // Semantic colors that adapt to color scheme via system dynamic colors.
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let label = Color(.label)
    static let secondaryLabel = Color(.secondaryLabel)
    static let separator = Color(.separator)

    static let danger = Color(hex: 0xFF5757)
    static let warning = Color(hex: 0xF59E0B)
    static let success = Color(hex: 0x34D399)

    // Spacing scale.
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

    /// Drawer open/close animation — matches the web drawer feel (~0.26s spring).
    static let drawerAnimation: Animation = .spring(response: 0.26, dampingFraction: 0.86)
}

// MARK: - App theme preference (light / dark / system)

enum AppThemePreference: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
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
