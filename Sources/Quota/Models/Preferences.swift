import SwiftUI
import Combine

/// User settings, persisted in UserDefaults. Shared singleton so both the
/// AppKit status-item host and SwiftUI views observe the same instance.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    @AppStorage("iconConcept") private var iconConceptRaw: String = IconConcept.hamster.rawValue
    @AppStorage("colorCoding") var colorCoding: Bool = true
    @AppStorage("showPercent") var showPercent: Bool = true
    /// false = show consumed amount (기본), true = show remaining amount.
    /// Only flips the displayed number + gauge fill; color still tracks risk.
    @AppStorage("showRemaining") var showRemaining: Bool = false
    /// Which limit drives the menu-bar icon: 5-hour window vs weekly all-models.
    @AppStorage("menuBarMetric") private var menuBarMetricRaw: String = MenuBarMetric.fiveHour.rawValue
    /// Polling interval in seconds. 180 (the endpoint's safe floor) is the
    /// default — usage %s change slowly, so this is the freshest safe cadence.
    /// The option exists mainly as a 429 escape valve / battery saver.
    @AppStorage("pollIntervalSeconds") var pollIntervalSeconds: Int = 180
    @AppStorage("notifyThresholds") var notifyThresholds: Bool = true
    @AppStorage("pulseWhenCritical") var pulseWhenCritical: Bool = true

    var iconConcept: IconConcept {
        get { IconConcept(rawValue: iconConceptRaw) ?? .hamster }
        set { iconConceptRaw = newValue.rawValue; objectWillChange.send() }
    }

    var menuBarMetric: MenuBarMetric {
        get { MenuBarMetric(rawValue: menuBarMetricRaw) ?? .fiveHour }
        set { menuBarMetricRaw = newValue.rawValue; objectWillChange.send() }
    }

    private init() {}
}

enum MenuBarMetric: String, CaseIterable, Identifiable {
    case fiveHour = "fiveHour"
    case weekly = "weekly"
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fiveHour: return "5시간 한도"
        case .weekly:   return "주간(전체 모델)"
        }
    }
}
