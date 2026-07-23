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
    private var concept: IconConcept { prefs.iconConcept }

    private var shouldPulse: Bool {
        prefs.pulseWhenCritical && percent >= 90
    }

    var body: some View {
        HStack(spacing: 5) {
            UsageIconCanvas(concept: concept, percent: percent,
                            scheme: scheme, colorCoding: prefs.colorCoding)
            .frame(width: concept.menuBarSize.width, height: concept.menuBarSize.height)
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
