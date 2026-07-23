import SwiftUI

/// The status-bar content: usage icon + optional `NN%`. Hosted inside the
/// NSStatusItem button via NSHostingView. Colors adapt to the menu-bar
/// appearance; the icon pulses at ≥90% (per the design's alert behavior).
struct MenuBarIconView: View {
    @ObservedObject var model: UsageModel
    @ObservedObject var prefs: Preferences
    @Environment(\.colorScheme) private var scheme

    @State private var pulsing = false

    private var percent: Int { model.menuBarPercent }
    private var fraction: Double { Double(percent) / 100 }
    private var concept: IconConcept { prefs.iconConcept }

    private var iconColor: Color {
        let coded = prefs.colorCoding && concept.supportsColorCoding
        if coded { return Palette.statusColor(for: percent, colorCoding: true) }
        // Monochrome: adapt to the menu bar (light glyph on dark bar).
        return scheme == .dark ? Palette.hamsterDark : Palette.mono
    }
    private var trackColor: Color {
        scheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.16)
    }

    private var iconSize: CGSize {
        switch concept {
        case .battery: return CGSize(width: 22, height: 15)
        case .hamster: return CGSize(width: 23, height: 21)
        case .liquid:  return CGSize(width: 15, height: 17)
        default:       return CGSize(width: 17, height: 17)
        }
    }

    private var shouldPulse: Bool {
        prefs.pulseWhenCritical && percent >= 90
    }

    var body: some View {
        HStack(spacing: 5) {
            UsageIconCanvas(
                concept: concept,
                fraction: fraction,
                color: iconColor,
                trackColor: trackColor,
                hamsterSilhouette: scheme == .dark ? Palette.hamsterDark : Palette.hamsterLight,
                hamsterFace: scheme == .dark ? Palette.hamsterFaceDark : Palette.hamsterFaceLight
            )
            .frame(width: iconSize.width, height: iconSize.height)
            .scaleEffect(pulsing ? 1.14 : 1.0)
            .animation(shouldPulse
                       ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
                       : .default,
                       value: pulsing)

            if prefs.showPercent {
                Text("\(percent)%")
                    .font(.system(size: 12.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 2)
        .fixedSize()
        .onAppear { pulsing = shouldPulse }
        .onChange(of: shouldPulse) { _, now in pulsing = now }
    }
}
