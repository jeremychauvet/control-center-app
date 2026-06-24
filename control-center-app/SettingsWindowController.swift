import AppKit
import SwiftUI

/// Owns the single Control Center settings window. Showing it promotes the app
/// to a regular (Dock-visible) app; closing it returns to a menu-bar-only agent.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?

    private let store: KeybindingStore
    private let accessibility: AccessibilityService
    private let launchAtLogin: LaunchAtLoginService
    private let presence: PresenceService
    private let keepAwake: KeepAwakeService

    init(
        store: KeybindingStore,
        accessibility: AccessibilityService,
        launchAtLogin: LaunchAtLoginService,
        presence: PresenceService,
        keepAwake: KeepAwakeService
    ) {
        self.store = store
        self.accessibility = accessibility
        self.launchAtLogin = launchAtLogin
        self.presence = presence
        self.keepAwake = keepAwake
        super.init()
    }

    /// Creates the window on first call and reuses it afterwards.
    func show() {
        let window = window ?? makeWindow()
        self.window = window

        // Become a regular app so the Dock icon and app menu appear while the
        // window is open.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let root = ControlCenterView()
            .environment(store)
            .environment(accessibility)
            .environment(launchAtLogin)
            .environment(presence)
            .environment(keepAwake)

        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Control Center"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 720, height: 480))
        window.contentMinSize = NSSize(width: 640, height: 440)
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu-bar-only agent: hide the Dock icon again.
        NSApp.setActivationPolicy(.accessory)
    }
}
