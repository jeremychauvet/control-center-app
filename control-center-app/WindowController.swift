import AppKit
import ApplicationServices
import Foundation

/// Reads and writes window geometry via the Accessibility API.
/// The protocol exists so WindowAnimator can be unit-tested against a fake.
@MainActor
protocol WindowControlling: AnyObject {
    func focusedWindow() -> AXUIElement?
    func frame(of window: AXUIElement) -> CGRect?
    func setFrame(_ frame: CGRect, on window: AXUIElement)
    func setPosition(_ position: CGPoint, on window: AXUIElement)
    func setSize(_ size: CGSize, on window: AXUIElement)
    func minimize(_ window: AXUIElement)
}

@MainActor
final class WindowController: WindowControlling {
    func focusedWindow() -> AXUIElement? {
        // The system-wide AX element's kAXFocusedApplicationAttribute is unreliable
        // for Electron/Chromium apps (VS Code, Chrome) — it returns nil even when
        // the app is clearly frontmost. NSWorkspace reads from a separate, reliable
        // source, so we resolve the app via PID and build the AX element ourselves.
        guard let app = NSWorkspace.shared.frontmostApplication else {
            NSLog("WindowController: no frontmost application")
            return nil
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if let win = copyAttribute(appElement, kAXFocusedWindowAttribute) {
            return (win as! AXUIElement)
        }
        if let win = copyAttribute(appElement, kAXMainWindowAttribute) {
            NSLog("WindowController: focused window missing, using main window")
            return (win as! AXUIElement)
        }
        if let windows = copyAttribute(appElement, kAXWindowsAttribute) as? [AXUIElement],
           let first = windows.first {
            NSLog("WindowController: focused/main window missing, using first window")
            return first
        }
        NSLog("WindowController: frontmost app \(app.localizedName ?? "?") exposes no usable window")
        return nil
    }

    func frame(of window: AXUIElement) -> CGRect? {
        guard let position = readPoint(window, attribute: kAXPositionAttribute),
              let size = readSize(window, attribute: kAXSizeAttribute) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    func setFrame(_ frame: CGRect, on window: AXUIElement) {
        // Set position first, then size — some apps clamp size against the screen
        // edge before applying the position, which causes drift.
        setPosition(frame.origin, on: window)
        setSize(frame.size, on: window)
    }

    func setPosition(_ position: CGPoint, on window: AXUIElement) {
        var pos = position
        guard let value = AXValueCreate(.cgPoint, &pos) else { return }
        let status = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
        if status != .success {
            NSLog("WindowController: setPosition failed status=\(status.rawValue)")
        }
    }

    func setSize(_ size: CGSize, on window: AXUIElement) {
        var sz = size
        guard let value = AXValueCreate(.cgSize, &sz) else { return }
        let status = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
        if status != .success {
            NSLog("WindowController: setSize failed status=\(status.rawValue)")
        }
    }

    func minimize(_ window: AXUIElement) {
        let status = AXUIElementSetAttributeValue(
            window, kAXMinimizedAttribute as CFString, kCFBooleanTrue
        )
        if status != .success {
            NSLog("WindowController: minimize failed status=\(status.rawValue)")
        }
    }

    private func copyAttribute(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attribute as CFString, &ref)
        guard err == .success else { return nil }
        return ref
    }

    private func readPoint(_ element: AXUIElement, attribute: String) -> CGPoint? {
        guard let raw = copyAttribute(element, attribute) else { return nil }
        let value = raw as! AXValue
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private func readSize(_ element: AXUIElement, attribute: String) -> CGSize? {
        guard let raw = copyAttribute(element, attribute) else { return nil }
        let value = raw as! AXValue
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }
}
