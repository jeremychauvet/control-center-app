import AppKit
import SwiftUI

@main
struct ControlCenterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // App is menu-bar only (LSUIElement). Settings scene is a no-op stub —
        // all UI lives in the status item popover managed by AppDelegate.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: KeybindingStore?
    private var accessibility: AccessibilityService?
    private var windowManager: WindowManager?
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-braces in case LSUIElement isn't picked up: hide from Dock too.
        NSApp.setActivationPolicy(.accessory)

        let store = KeybindingStore()
        let accessibility = AccessibilityService()
        let windowManager = WindowManager(store: store, accessibility: accessibility)
        let menuBar = MenuBarController(
            store: store,
            accessibility: accessibility,
            windowManager: windowManager
        )
        menuBar.install()

        self.store = store
        self.accessibility = accessibility
        self.windowManager = windowManager
        self.menuBar = menuBar

        // Soft-prompt for Accessibility on first launch. If denied the popover
        // shows a "permission needed" banner with a one-click grant path.
        if !accessibility.isTrusted {
            accessibility.requestTrust()
        }
    }
}
