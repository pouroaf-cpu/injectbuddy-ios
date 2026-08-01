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
    @Published var units: UnitSystem { didSet { save(.units, units.rawValue) } }
    @Published var syringeScale: SyringeScale { didSet { save(.syringe, syringeScale.rawValue) } }

    /// First-run medical disclaimer acceptance. The app gates behind this once
    /// (App Review expects a prominent "not medical advice" acknowledgement).
    @Published var hasAcceptedDisclaimer: Bool {
        didSet { defaults.set(hasAcceptedDisclaimer, forKey: Key.disclaimer.rawValue) }
    }

    private enum Key: String {
        /// Retired 2026-08-01 when the app went light-only. Kept only so the
        /// stored value can be deleted on launch — see `migrateAwayFromTheme`.
        case retiredTheme = "ib_theme_pref"
        case units = "ib_units"
        case syringe = "ib_syringe_scale"
        case disclaimer = "ib_disclaimer_accepted_v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        units = UnitSystem(rawValue: defaults.string(forKey: Key.units.rawValue) ?? "") ?? .metric
        syringeScale = SyringeScale(rawValue: defaults.string(forKey: Key.syringe.rawValue) ?? "") ?? .u100
        hasAcceptedDisclaimer = defaults.bool(forKey: Key.disclaimer.rawValue)
        Self.migrateAwayFromTheme(defaults)
    }

    /// Upgrade path for installs from a build that had a theme picker. The old
    /// value was a bare String, never a decoded Codable enum, so a leftover
    /// "dark" could not have crashed on read — but it is removed anyway so the
    /// key doesn't linger as a false signal that the preference still exists.
    private static func migrateAwayFromTheme(_ defaults: UserDefaults) {
        guard defaults.object(forKey: Key.retiredTheme.rawValue) != nil else { return }
        defaults.removeObject(forKey: Key.retiredTheme.rawValue)
    }

    private let defaults: UserDefaults
    private func save(_ key: Key, _ value: String) { defaults.set(value, forKey: key.rawValue) }
}
