import AppKit
import SwiftUI

/// Owns the NSStatusItem and the popover containing the settings UI.
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    private let store: KeybindingStore
    private let accessibility: AccessibilityService
    private let windowManager: WindowManager

    init(store: KeybindingStore, accessibility: AccessibilityService, windowManager: WindowManager) {
        self.store = store
        self.accessibility = accessibility
        self.windowManager = windowManager
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.badge.sparkles",
                accessibilityDescription: "Control Center"
            )
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        self.statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: SettingsView()
                .environment(store)
                .environment(accessibility)
        )
        self.popover = popover
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
