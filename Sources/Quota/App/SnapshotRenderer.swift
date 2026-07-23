import SwiftUI
import AppKit

/// Offscreen PNG rendering for visual QA (no screen-recording permission
/// needed). Triggered by the QUOTA_SNAPSHOT=<dir> env var; renders reference
/// images then exits.
@MainActor
enum SnapshotRenderer {
    static func runIfRequested() -> Bool {
        guard let dir = ProcessInfo.processInfo.environment["QUOTA_SNAPSHOT"] else { return false }
        let base = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        write(MenuBarStrip().frame(width: 520, height: 44), to: base, "menubar_strip", scale: 3)
        write(IconGrid(), to: base, "icon_grid", scale: 2)
        write(PopoverPreview(), to: base, "popover", scale: 2)

        return true
    }

    private static func write<V: View>(_ view: V, to dir: URL, _ name: String, scale: CGFloat) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

// MARK: - Preview views

/// Dark menu-bar mock showing the default (Hamster) + Donut + Ring at 3 levels.
private struct MenuBarStrip: View {
    var body: some View {
        HStack(spacing: 22) {
            ForEach([(IconConcept.hamster, 20), (.donut, 60), (.ring, 95),
                     (.battery, 45), (.liquid, 80)], id: \.1) { concept, pct in
                HStack(spacing: 5) {
                    UsageIconCanvas(concept: concept, percent: pct,
                                    scheme: .dark, colorCoding: true)
                    .frame(width: concept.menuBarSize.width, height: concept.menuBarSize.height)
                    Text("\(pct)%")
                        .font(.system(size: 12.5, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: 0x2C2C30))
    }
}

/// All six concepts across five usage levels, on dark, matching the handoff grid.
private struct IconGrid: View {
    let levels = [0, 25, 50, 75, 100]
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(IconConcept.allCases) { concept in
                HStack(spacing: 20) {
                    Text(concept.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white).frame(width: 72, alignment: .leading)
                    ForEach(levels, id: \.self) { pct in
                        VStack(spacing: 6) {
                            UsageIconCanvas(concept: concept, percent: pct,
                                            scheme: .dark, colorCoding: true)
                            .frame(width: 40, height: 36)
                            Text("\(pct)%").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                        }.frame(width: 60)
                    }
                }
            }
        }
        .padding(24)
        .background(Color(hex: 0x2C2C30))
    }
}

/// The live popover with sample data.
private struct PopoverPreview: View {
    var body: some View {
        PopoverView(
            model: UsageModel.shared, prefs: Preferences.shared,
            onOpenSettings: {}, onQuit: {}
        )
        .padding(24)
        .background(Color(hex: 0xE8E6E1))
    }
}
