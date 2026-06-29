import AppKit
import Carbon.HIToolbox
import Foundation

/// Registers global shortcuts for system utilities that aren't window-snapping
/// actions:
///   - Control+Shift+Escape launches Activity Monitor — borrowing the Windows
///     "Ctrl+Shift+Esc opens Task Manager" muscle memory (Activity Monitor is the
///     macOS equivalent).
///   - Command+L locks the screen (switches to the login window).
@MainActor
final class SystemShortcutsService {
    private let hotkeyManager: HotkeyManager
    private var activityMonitorHotkeyID: UInt32?
    private var lockScreenHotkeyID: UInt32?

    /// Control+Shift+Escape. Carbon's RegisterEventHotKey matches on a generic
    /// Shift modifier and can't distinguish left from right Shift, so this fires
    /// for either Shift key — the "Left Shift" in the request can't be enforced.
    static let activityMonitorCombo = KeyCombo(
        keyCode: UInt32(kVK_Escape),
        modifiers: UInt32(controlKey | shiftKey)
    )

    /// Command+L. Registered as a system-wide hotkey, so it consumes ⌘L globally
    /// (it will not reach the frontmost app). Chosen deliberately per the feature
    /// request.
    static let lockScreenCombo = KeyCombo(
        keyCode: UInt32(kVK_ANSI_L),
        modifiers: UInt32(cmdKey)
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

    /// Register the system shortcuts. Idempotent.
    func register() {
        if activityMonitorHotkeyID == nil {
            activityMonitorHotkeyID = hotkeyManager.register(combo: Self.activityMonitorCombo) {
                Self.launchActivityMonitor()
            }
        }
        if lockScreenHotkeyID == nil {
            lockScreenHotkeyID = hotkeyManager.register(combo: Self.lockScreenCombo) {
                Self.lockScreen()
            }
        }
    }

    func unregister() {
        if let id = activityMonitorHotkeyID {
            hotkeyManager.unregister(id: id)
            activityMonitorHotkeyID = nil
        }
        if let id = lockScreenHotkeyID {
            hotkeyManager.unregister(id: id)
            lockScreenHotkeyID = nil
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

    /// Lock the screen immediately (switch to the login window), the same effect
    /// as the menu-bar "Lock Screen" item. There is no public API for this, so we
    /// resolve `SACLockScreenImmediate()` from the private login.framework at
    /// runtime via dlsym — the long-standing technique used by lock utilities.
    /// Requires the app to be unsandboxed (it is: ENABLE_APP_SANDBOX = NO).
    static func lockScreen() {
        let path = "/System/Library/PrivateFrameworks/login.framework/Versions/Current/login"
        guard let handle = dlopen(path, RTLD_NOW) else {
            let reason = dlerror().map { String(cString: $0) } ?? "unknown"
            NSLog("SystemShortcutsService: failed to dlopen login.framework: \(reason)")
            return
        }
        defer { dlclose(handle) }
        guard let symbol = dlsym(handle, "SACLockScreenImmediate") else {
            NSLog("SystemShortcutsService: SACLockScreenImmediate not found in login.framework")
            return
        }
        typealias LockScreenFn = @convention(c) () -> Int32
        let lock = unsafeBitCast(symbol, to: LockScreenFn.self)
        let result = lock()
        if result != 0 {
            NSLog("SystemShortcutsService: SACLockScreenImmediate returned \(result)")
        }
    }
}
