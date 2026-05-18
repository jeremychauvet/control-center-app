import AppKit
import ApplicationServices
import Foundation
import Observation

/// Tracks whether the process is trusted for the Accessibility APIs, prompts the
/// user when needed, and polls so newly granted permission is picked up without
/// requiring a relaunch.
@Observable
final class AccessibilityService {
    private(set) var isTrusted: Bool

    @ObservationIgnored
    private var pollTimer: Timer?

    init() {
        self.isTrusted = AXIsProcessTrusted()
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    /// Re-check trust without showing a prompt.
    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }
    }

    /// Prompt the user (system dialog) to grant Accessibility permission. The
    /// result reflects current trust; the user must approve in System Settings,
    /// which we then pick up via polling.
    @discardableResult
    func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: kCFBooleanTrue] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        isTrusted = trusted
        return trusted
    }

    /// Opens the Accessibility pane of System Settings.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startPolling() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.pollTimer = timer
    }
}
