import SwiftUI

/// Design tokens from the Quota handoff. Single source of truth for colors.
///
/// Status color logic mirrors the prototype `makeStage()`:
///   pct < 50 → green, pct < 80 → amber, else red. Monochrome fallback otherwise.
enum Palette {
    // Status (usage) colors
    static let green = Color(hex: 0x3F9E69)
    static let amber = Color(hex: 0xD1962F)
    static let red   = Color(hex: 0xCF3B2C)
    static let mono  = Color(hex: 0x2B2B30)

    // Popover text
    static let textPrimary   = Color(hex: 0x1D1D1F)
    static let textSecondary = Color(hex: 0x86868B)
    static let textTertiary  = Color(hex: 0xA1A1A6)

    // Popover surfaces / lines
    static let popoverBG = Color(hex: 0xFBFBFD)
    static let hairline  = Color.black.opacity(0.07)
    static let border    = Color.black.opacity(0.08)
    static let track     = Color.black.opacity(0.07)
    static let trackBar  = Color.black.opacity(0.08)

    // Accents
    static let onlineDot = Color(hex: 0x34C759)
    static let fablePurple = Color(hex: 0xAF52DE)

    // Hamster silhouette / features (appearance-dependent)
    static let hamsterLight = Color(hex: 0x2B2B30) // silhouette on light menu bar
    static let hamsterDark  = Color(hex: 0xECEEF2) // silhouette on dark menu bar
    static let hamsterFaceLight = Color(hex: 0xFBFBFD) // features on light silhouette
    static let hamsterFaceDark  = Color(hex: 0x34343A) // features on dark silhouette

    /// Usage → status color, honoring the color-coding toggle.
    static func statusColor(for pct: Int, colorCoding: Bool) -> Color {
        guard colorCoding else { return mono }
        if pct < 50 { return green }
        if pct < 80 { return amber }
        return red
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
