import AppKit

/// A dedicated status-bar item for the "Keep me available" feature, shown when
/// `presence.showMenuBarIcon` is on. Its icon reflects the current state — hollow
/// circle when off, a warning when enabled but lacking Accessibility permission,
/// dotted while standing by, filled while actively injecting — and clicking it
/// toggles the feature on/off (prompting for permission if needed).
@MainActor
final class PresenceStatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private let presence: PresenceService

    init(presence: PresenceService) {
        self.presence = presence
        super.init()
    }

    /// Wires the state observer and applies the initial visibility/icon. Call once.
    func install() {
        presence.onStateChanged = { [weak self] in self?.refresh() }
        refresh()
    }

    /// Adds, updates, or removes the item to match the current state and the
    /// `showMenuBarIcon` setting.
    private func refresh() {
        guard presence.showMenuBarIcon else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            return
        }

        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: presence.menuBarSymbolName,
                accessibilityDescription: "Keep me available"
            )
            button.toolTip = presence.statusBarTooltip
            button.action = #selector(toggle)
            button.target = self
        }
        statusItem = item
    }

    @objc private func toggle() {
        presence.setEnabled(!presence.isEnabled)
    }
}
