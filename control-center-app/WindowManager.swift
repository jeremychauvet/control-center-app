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
        guard let window = windowController.focusedWindow() else { return }

        if action == .minimize {
            windowController.minimize(window)
            return
        }

        guard let current = windowController.frame(of: window),
              let screen = ScreenLayout.screen(forAXFrame: current) else {
            return
        }
        let margin = Self.systemTileMargin
        let region = ScreenLayout.region(for: action)

        // Cross-display chaining: pressing e.g. left-half on a window that's
        // already snapped to the left half of its screen hops the window to the
        // right half of the screen physically to the left (if one exists).
        // Same idea for the other three halves. Maximize/Center don't chain.
        var targetScreen = screen
        var targetRegion = region
        if let direction = Self.chainDirection(for: action) {
            let here = ScreenLayout.targetFrame(
                for: region, on: screen, margin: margin, currentAXFrame: current
            )
            if Self.frame(current, matches: here, within: Self.snapMatchTolerance),
               let neighbor = ScreenLayout.neighborScreen(of: screen, direction: direction) {
                targetScreen = neighbor
                targetRegion = Self.opposite(region)
            }
        }

        let target = ScreenLayout.targetFrame(
            for: targetRegion,
            on: targetScreen,
            margin: margin,
            currentAXFrame: current
        )
        if store.animationEnabled {
            animator.animate(window, to: target, duration: store.animationDuration)
        } else {
            windowController.setFrame(target, on: window)
        }
    }

    /// Tolerance for deciding a window is "already" at a target frame. Loose
    /// enough to absorb apps that clamp size to a character grid (Terminal,
    /// editors), tight enough that a non-snapped window isn't mistaken for one.
    private static let snapMatchTolerance: CGFloat = 10

    private static func frame(_ a: CGRect, matches b: CGRect, within tol: CGFloat) -> Bool {
        abs(a.minX - b.minX) < tol &&
        abs(a.minY - b.minY) < tol &&
        abs(a.width - b.width) < tol &&
        abs(a.height - b.height) < tol
    }

    private static func chainDirection(for action: WindowAction) -> ScreenDirection? {
        switch action {
        case .leftHalf:   return .left
        case .rightHalf:  return .right
        case .topHalf:    return .up
        case .bottomHalf: return .down
        case .maximize, .center, .minimize: return nil
        }
    }

    private static func opposite(_ region: ScreenRegion) -> ScreenRegion {
        switch region {
        case .leftHalf:   return .rightHalf
        case .rightHalf:  return .leftHalf
        case .topHalf:    return .bottomHalf
        case .bottomHalf: return .topHalf
        case .maximize, .center: return region
        }
    }
}
