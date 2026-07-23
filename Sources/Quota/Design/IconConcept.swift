import CoreGraphics
import Foundation

/// The six menu-bar icon styles from the design handoff.
/// `hamster` is intentionally always monochrome (shape conveys usage).
enum IconConcept: String, CaseIterable, Identifiable, Codable {
    case hamster = "Hamster"
    case donut   = "Donut"
    case ring    = "Ring"
    case eclipse = "Eclipse"
    case battery = "Battery"
    case liquid  = "Liquid"

    var id: String { rawValue }

    /// Localized display name for the settings picker.
    var displayName: String {
        switch self {
        case .hamster: return "햄스터 볼"
        case .donut:   return "도넛 차트"
        case .ring:    return "링 게이지"
        case .eclipse: return "잠식 원반"
        case .battery: return "배터리"
        case .liquid:  return "액체 채움"
        }
    }

    /// Hamster ignores color coding (always mono).
    var supportsColorCoding: Bool { self != .hamster }

    /// Render size in the menu bar (some glyphs are wider/taller than square).
    var menuBarSize: CGSize {
        switch self {
        case .battery: return CGSize(width: 22, height: 15)
        case .hamster: return CGSize(width: 23, height: 21)
        case .liquid:  return CGSize(width: 15, height: 17)
        default:       return CGSize(width: 17, height: 17)
        }
    }
}
