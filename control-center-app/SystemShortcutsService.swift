import AppKit
import Carbon.HIToolbox
import Foundation

/// Registers global shortcuts for system utilities that aren't window-snapping
/// actions. Currently: Control+Shift+Escape launches Activity Monitor — borrowing
/// the Windows "Ctrl+Shift+Esc opens Task Manager" muscle memory (Activity Monitor
/// is the macOS equivalent).
@MainActor
final class SystemShortcutsService {
    private let hotkeyManager: HotkeyManager
    private var activityMonitorHotkeyID: UInt32?

    /// Control+Shift+Escape. Carbon's RegisterEventHotKey matches on a generic
    /// Shift modifier and can't distinguish left from right Shift, so this fires
    /// for either Shift key — the "Left Shift" in the request can't be enforced.
    static let activityMonitorCombo = KeyCombo(
        keyCode: UInt32(kVK_Escape),
        modifiers: UInt32(controlKey | shiftKey)
    )

    /// Bundle identifier for Activity Monitor, the macOS equivalent of Task Manager.
    static let activityMonitorBundleID = "com.apple.ActivityMonitor"

    /// Shares the app-wide HotkeyManager. A second HotkeyManager would install a
    /// second Carbon event handler on the same event target; because our handler
    /// always returns noErr (consuming the event), whichever handler runs first
    /// would swallow every press and the other's hotkeys would never fire.
    init(hotkeyManager: HotkeyManager) {
        self.hotkeyManager = hotkeyManager
    }

    /// Register the Activity Monitor shortcut. Idempotent.
    func register() {
        guard activityMonitorHotkeyID == nil else { return }
        activityMonitorHotkeyID = hotkeyManager.register(combo: Self.activityMonitorCombo) {
            Self.launchActivityMonitor()
        }
    }

    func unregister() {
        if let id = activityMonitorHotkeyID {
            hotkeyManager.unregister(id: id)
            activityMonitorHotkeyID = nil
        }
    }

    static func launchActivityMonitor() {
        let workspace = NSWorkspace.shared
        guard let url = workspace.urlForApplication(withBundleIdentifier: activityMonitorBundleID) else {
            NSLog("SystemShortcutsService: Activity Monitor (\(activityMonitorBundleID)) not found")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        workspace.openApplication(at: url, configuration: config) { _, error in
            if let error {
                NSLog("SystemShortcutsService: failed to launch Activity Monitor: \(error)")
            }
        }
    }
}
