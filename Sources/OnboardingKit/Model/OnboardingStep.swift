import Foundation

/// The thirteen screens of the flow. SPEC §3 — "The route".
///
/// The case order is the route order of the LONG path. It is not the route
/// itself: the route is `OnboardingRoute.steps(for:)`, because `.adv` removes
/// two of these entirely.
enum OnboardingStep: String, CaseIterable, Hashable {
    case welcome      // 1
    case pathway      // 2  — branch dimension 1, mandatory, sets `segment`
    case experience   // 3  — branch dimension 2, mandatory, sets `exp`
    case benefit1     // 4a — copy by `segment`
    case benefit2     // 4b — removed entirely when `exp == .adv`
    case benefit3     // 4c — removed entirely when `exp == .adv`
    case setup        // 5  — required fields
    case reminders    // 6  — optional, skippable
    case inventory    // 7  — optional, skippable
    case firstDose    // 8  — core value BEFORE the paywall
    case paywall      // 9  — headline by `segment`
    case dashboard    // 10a — end state, accepted
    case locked       // 10b — end state, declined

    /// Progress-bar percentage, exactly as SPEC §3 tabulates it. `nil` on the
    /// two end states, which carry no bar.
    ///
    /// **Integer percent, not a fraction, on purpose.** SPEC §7: "The bar
    /// percentages are the one thing worth asserting rather than eyeballing,
    /// because they are exact and they are easy to get wrong in a refactor." An
    /// `Int` compares exactly; a `Double` invites an epsilon.
    ///
    /// The bar STARTS AT 25% (endowed progress) — that is design, not an
    /// off-by-one.
    var barPercent: Int? {
        switch self {
        case .welcome:    return 25
        case .pathway:    return 35
        case .experience: return 45
        case .benefit1:   return 55
        case .benefit2:   return 62
        case .benefit3:   return 69
        case .setup:      return 76
        case .reminders:  return 84
        case .inventory:  return 90
        case .firstDose:  return 97
        case .paywall:    return 100
        case .dashboard:  return nil
        case .locked:     return nil
        }
    }

    /// 0…1 for a `ProgressView` / bar width. `nil` where there is no bar.
    var barFraction: Double? {
        barPercent.map { Double($0) / 100 }
    }

    /// The two terminals. Both loop back to `welcome` — SPEC §1.
    var isEndState: Bool {
        switch self {
        case .dashboard, .locked:
            return true
        case .welcome, .pathway, .experience, .benefit1, .benefit2, .benefit3,
             .setup, .reminders, .inventory, .firstDose, .paywall:
            return false
        }
    }

    /// The `OnboardingSkippableStep` this screen corresponds to, if any.
    /// Enumerated rather than name-matched.
    var skippable: OnboardingSkippableStep? {
        switch self {
        case .reminders: return .reminders
        case .inventory: return .inventory
        case .firstDose: return .firstDose
        case .welcome, .pathway, .experience, .benefit1, .benefit2, .benefit3,
             .setup, .paywall, .dashboard, .locked:
            return nil
        }
    }
}

/// The two end states, as a closed type. Handed to the sink so a caller cannot
/// be handed `.setup` and have to guess.
enum OnboardingEndState: String, CaseIterable, Hashable {
    case dashboard
    case locked

    var step: OnboardingStep {
        switch self {
        case .dashboard: return .dashboard
        case .locked:    return .locked
        }
    }
}
