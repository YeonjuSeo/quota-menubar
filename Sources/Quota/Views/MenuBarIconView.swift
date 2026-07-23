import SwiftUI

/// The status-bar content: usage icon + optional `NN%`. Hosted inside the
/// NSStatusItem button via NSHostingView. Colors adapt to the menu-bar
/// appearance; the icon pulses at ≥90% (per the design's alert behavior).
struct MenuBarIconView: View {
    @ObservedObject var model: UsageModel
    @ObservedObject var prefs: Preferences
    @Environment(\.colorScheme) private var scheme

    @State private var pulsing = false

    private var usedPercent: Int { model.menuBarPercent }
    private var concept: IconConcept { prefs.iconConcept }
    private var displayPercent: Int {
        prefs.showRemaining ? 100 - usedPercent : usedPercent
    }

    /// Pulse always keys off risk (consumed), regardless of display mode.
    private var shouldPulse: Bool {
        prefs.pulseWhenCritical && usedPercent >= 90
    }

    var body: some View {
        HStack(spacing: 5) {
            UsageIconCanvas(concept: concept, usedPercent: usedPercent,
                            showRemaining: prefs.showRemaining,
                            scheme: scheme, colorCoding: prefs.colorCoding)
            .frame(width: concept.menuBarSize.width, height: concept.menuBarSize.height)
            .scaleEffect(pulsing ? 1.14 : 1.0)
            .animation(shouldPulse
                       ? .easeInOut(duration: 0.55).repeatForever(autoreverses: true)
                       : .default,
                       value: pulsing)

            if prefs.showPercent {
                Text("\(displayPercent)%")
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
