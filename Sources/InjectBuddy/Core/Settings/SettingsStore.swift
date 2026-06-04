import SwiftUI

// ─── Shared preference enums ─────────────────────────────────────────────────

enum UnitSystem: String, CaseIterable, Identifiable, Codable {
    case metric, imperial
    var id: String { rawValue }
    var label: String { self == .metric ? "Metric" : "Imperial" }
}

/// Insulin-syringe scale used when showing "units to draw". U-100 = 100 units/mL.
enum SyringeScale: String, CaseIterable, Identifiable, Codable {
    case u100, u40
    var id: String { rawValue }
    var label: String { self == .u100 ? "U-100" : "U-40" }
    var unitsPerML: Double { self == .u100 ? 100 : 40 }
}

// ─── SettingsStore ───────────────────────────────────────────────────────────
// App-wide preferences (theme, units, syringe scale), persisted to UserDefaults.
// Shared by the App (color scheme), the drawer (theme toggle), the calculators
// (units / syringe scale), and the SettingsScreen UI. SettingsScreen builds on top
// of this store — it does not redefine it.

@MainActor
final class SettingsStore: ObservableObject {
    @Published var theme: AppThemePreference { didSet { save(.theme, theme.rawValue) } }
    @Published var units: UnitSystem { didSet { save(.units, units.rawValue) } }
    @Published var syringeScale: SyringeScale { didSet { save(.syringe, syringeScale.rawValue) } }

    /// First-run medical disclaimer acceptance. The app gates behind this once
    /// (App Review expects a prominent "not medical advice" acknowledgement).
    @Published var hasAcceptedDisclaimer: Bool {
        didSet { defaults.set(hasAcceptedDisclaimer, forKey: Key.disclaimer.rawValue) }
    }

    private enum Key: String {
        case theme = "ib_theme_pref"
        case units = "ib_units"
        case syringe = "ib_syringe_scale"
        case disclaimer = "ib_disclaimer_accepted_v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        theme = AppThemePreference(rawValue: defaults.string(forKey: Key.theme.rawValue) ?? "") ?? .system
        units = UnitSystem(rawValue: defaults.string(forKey: Key.units.rawValue) ?? "") ?? .metric
        syringeScale = SyringeScale(rawValue: defaults.string(forKey: Key.syringe.rawValue) ?? "") ?? .u100
        hasAcceptedDisclaimer = defaults.bool(forKey: Key.disclaimer.rawValue)
    }

    private let defaults: UserDefaults
    private func save(_ key: Key, _ value: String) { defaults.set(value, forKey: key.rawValue) }

    /// Footer toggle cycles system → light → dark → system.
    func cycleTheme() {
        switch theme {
        case .system: theme = .light
        case .light: theme = .dark
        case .dark: theme = .system
        }
    }
}
