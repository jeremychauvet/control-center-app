import AppKit
import ApplicationServices
import CoreFoundation
import Foundation

/// Ties the layers together: subscribes to keybinding changes, registers Carbon
/// hotkeys, and on a hotkey press snaps the frontmost app's focused window.
@MainActor
final class WindowManager {
    private let hotkeyManager: HotkeyManager
    private let windowController: WindowControlling
    private let animator: WindowAnimator
    private let accessibility: AccessibilityService
    private let store: KeybindingStore
    private var hotkeyIDs: [WindowAction: UInt32] = [:]

    init(store: KeybindingStore, accessibility: AccessibilityService) {
        self.store = store
        self.accessibility = accessibility
        self.hotkeyManager = HotkeyManager()
        let controller = WindowController()
        self.windowController = controller
        self.animator = WindowAnimator(controller: controller)

        store.onBindingsChanged = { [weak self] in
            guard let self else { return }
            self.reregister(bindings: store.bindings)
        }
        reregister(bindings: store.bindings)
    }

    /// Re-register all hotkeys. Called on init and whenever the user remaps a key.
    private func reregister(bindings: [WindowAction: KeyCombo]) {
        for (_, id) in hotkeyIDs {
            hotkeyManager.unregister(id: id)
        }
        hotkeyIDs.removeAll()

        for (action, combo) in bindings {
            let id = hotkeyManager.register(combo: combo) { [weak self] in
                self?.perform(action: action)
            }
            if let id { hotkeyIDs[action] = id }
        }
    }

    /// Inset applied to tiled windows when the macOS "Tiled windows have margins"
    /// setting (com.apple.WindowManager / EnableTiledWindowMargins) is enabled.
    /// Matches the appearance of macOS's own tiling.
    private static let tileMarginPoints: CGFloat = 8

    private static var systemTileMargin: CGFloat {
        let enabled = CFPreferencesCopyAppValue(
            "EnableTiledWindowMargins" as CFString,
            "com.apple.WindowManager" as CFString
        ) as? Bool ?? false
        return enabled ? tileMarginPoints : 0
    }

    func perform(action: WindowAction) {
        // Gracefully degrade if permission was revoked while running.
        guard accessibility.isTrusted else {
            accessibility.requestTrust()
            return
        }
        guard let window = windowController.focusedWindow(),
              let current = windowController.frame(of: window),
              let screen = ScreenLayout.screen(forAXFrame: current) else {
            return
        }
        let region = ScreenLayout.region(for: action)
        let target = ScreenLayout.targetFrame(
            for: region,
            on: screen,
            margin: Self.systemTileMargin,
            currentAXFrame: current
        )
        if store.animationEnabled {
            animator.animate(window, to: target, duration: store.animationDuration)
        } else {
            windowController.setFrame(target, on: window)
        }
    }
}
