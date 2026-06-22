import AppKit

/// Owns the NSStatusItem. Clicking it shows a small menu whose primary action
/// opens the Control Center window (via `SettingsWindowController`).
@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let windowController: SettingsWindowController

    init(windowController: SettingsWindowController) {
        self.windowController = windowController
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.badge.sparkles",
                accessibilityDescription: "Control Center"
            )
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open Control Center\u{2026}",
            action: #selector(openControlCenter),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Control Center",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
    }

    @objc private func openControlCenter() {
        windowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
