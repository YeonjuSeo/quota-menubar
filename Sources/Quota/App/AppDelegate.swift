import SwiftUI
import AppKit
import Combine

/// An NSHostingView that lets mouse events fall through to the status-item
/// button underneath, so the button's click action still fires while the
/// SwiftUI icon keeps animating (e.g. the ≥90% pulse).
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var hostingView: PassthroughHostingView<MenuBarIconView>!
    private var cancellables = Set<AnyCancellable>()

    private let model = UsageModel.shared
    private let prefs = Preferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // QA hook: render reference PNGs offscreen, then exit.
        if SnapshotRenderer.runIfRequested() {
            DispatchQueue.main.async { NSApp.terminate(nil) }
            return
        }

        NSApp.setActivationPolicy(.accessory) // menu-bar only, no Dock icon

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let icon = MenuBarIconView(model: model, prefs: prefs)
        hostingView = PassthroughHostingView(rootView: icon)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        if let button = statusItem.button {
            button.addSubview(hostingView)
            NSLayoutConstraint.activate([
                hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor)
            ])
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover = NSPopover()
        popover.behavior = .transient
        let content = PopoverView(
            model: model, prefs: prefs,
            onOpenSettings: { [weak self] in self?.openSettings() },
            onQuit: { NSApp.terminate(nil) }
        )
        let hc = NSHostingController(rootView: content)
        hc.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hc

        // Keep the status-item width in sync with icon content.
        model.$snapshot.receive(on: RunLoop.main).sink { [weak self] _ in self?.resizeStatusItem() }
            .store(in: &cancellables)
        prefs.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            DispatchQueue.main.async { self?.resizeStatusItem() }
        }.store(in: &cancellables)

        resizeStatusItem()
        model.start()
    }

    private func resizeStatusItem() {
        hostingView.layoutSubtreeIfNeeded()
        let w = max(24, hostingView.fittingSize.width)
        statusItem.length = w
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func openSettings() {
        popover.performClose(nil)
        if let win = settingsWindow {
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let view = SettingsView(model: model, prefs: prefs)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        win.title = "Quota 설정"
        win.contentViewController = NSHostingController(rootView: view)
        win.center()
        win.isReleasedWhenClosed = false
        settingsWindow = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
