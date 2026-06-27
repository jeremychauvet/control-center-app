import AppKit
import SwiftUI

@main
struct ControlCenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // App launches menu-bar only (LSUIElement). The settings window is an
        // AppKit NSWindow managed by SettingsWindowController; this scene is a
        // no-op stub.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: KeybindingStore?
    private var accessibility: AccessibilityService?
    private var launchAtLogin: LaunchAtLoginService?
    private var windowManager: WindowManager?
    private var systemShortcuts: SystemShortcutsService?
    private var presence: PresenceService?
    private var presenceStatus: PresenceStatusItemController?
    private var keepAwake: KeepAwakeService?
    private var settingsWindow: SettingsWindowController?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-braces in case LSUIElement isn't picked up: hide from Dock too.
        // SettingsWindowController flips this to .regular while the window is open.
        NSApp.setActivationPolicy(.accessory)

        let store = KeybindingStore()
        let accessibility = AccessibilityService()
        let launchAtLogin = LaunchAtLoginService()
        // A single HotkeyManager is shared across all global-shortcut owners.
        // Each HotkeyManager installs a Carbon event handler that consumes the
        // event, so multiple managers would swallow each other's hotkeys.
        let hotkeyManager = HotkeyManager()
        let windowManager = WindowManager(
            store: store,
            accessibility: accessibility,
            hotkeyManager: hotkeyManager
        )
        let systemShortcuts = SystemShortcutsService(hotkeyManager: hotkeyManager)
        systemShortcuts.register()
        let presence = PresenceService(accessibility: accessibility)
        // The presence status-bar item observes presence state; install it
        // before restore() so a persisted-on feature shows its item immediately.
        let presenceStatus = PresenceStatusItemController(presence: presence)
        presenceStatus.install()
        // Re-apply persisted presence state (start keep-alive loop).
        presence.restore()

        let keepAwake = KeepAwakeService()
        keepAwake.restore()

        let settingsWindow = SettingsWindowController(
            store: store,
            accessibility: accessibility,
            launchAtLogin: launchAtLogin,
            presence: presence,
            keepAwake: keepAwake
        )
        let menuBar = MenuBarController(windowController: settingsWindow)
        menuBar.install()

        self.store = store
        self.accessibility = accessibility
        self.launchAtLogin = launchAtLogin
        self.windowManager = windowManager
        self.systemShortcuts = systemShortcuts
        self.presence = presence
        self.presenceStatus = presenceStatus
        self.keepAwake = keepAwake
        self.settingsWindow = settingsWindow
        self.menuBar = menuBar

        // Soft-prompt for Accessibility on first launch. If denied, the General
        // pane shows a "permission needed" banner with a one-click grant path.
        if !accessibility.isTrusted {
            accessibility.requestTrust()
        }
    }
}
