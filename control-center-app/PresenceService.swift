import CoreGraphics
import Foundation
import IOKit.pwr_mgt
import Observation

/// Keeps you "Available" in apps like Microsoft Teams by detecting idle time and
/// injecting an invisible F15 key event, and optionally prevents the Mac from
/// sleeping. Ported from the standalone "I Am Here" app and adapted to Control
/// Center's `@Observable` + UserDefaults conventions.
///
/// Injecting events requires Accessibility trust, so the keep-alive loop only
/// runs when the feature is enabled *and* the process is trusted; otherwise the
/// mode reports `.needsPermission` rather than silently doing nothing. (Keeping
/// the Mac awake needs no permission and is managed independently.)
@MainActor
@Observable
final class PresenceService {

    enum Mode: String {
        case disabled
        case needsPermission
        case standby
        case keepingAlive
    }

    private(set) var mode: Mode = .disabled {
        didSet {
            guard oldValue != mode else { return }
            onStateChanged?()
        }
    }

    /// The user's intent. Whether the loop actually runs also depends on
    /// Accessibility trust — see `reconcile()`. Prefer `setEnabled(_:)`, which
    /// also prompts for permission when enabling while untrusted.
    var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            reconcile()
        }
    }

    var idleThreshold: TimeInterval {
        didSet {
            guard oldValue != idleThreshold else { return }
            defaults.set(idleThreshold, forKey: Keys.idleThreshold)
        }
    }

    /// Whether to show the dedicated "Keep me available" status-bar item.
    var showMenuBarIcon: Bool {
        didSet {
            guard oldValue != showMenuBarIcon else { return }
            defaults.set(showMenuBarIcon, forKey: Keys.showMenuBarIcon)
            onStateChanged?()
        }
    }

    private(set) var lastInjectionAt: Date?

    var preventSleep: Bool {
        didSet {
            guard oldValue != preventSleep else { return }
            defaults.set(preventSleep, forKey: Keys.preventSleep)
            if preventSleep { acquireSleepAssertion() } else { releaseSleepAssertion() }
        }
    }

    @ObservationIgnored private let accessibility: AccessibilityService

    @ObservationIgnored private var sleepAssertionID: IOPMAssertionID = 0
    @ObservationIgnored private var hasSleepAssertion = false

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let tickInterval: TimeInterval = 5
    @ObservationIgnored private let injectionGrace: TimeInterval = 1.0
    @ObservationIgnored private var lastUserActivityAt: Date = Date()

    // Events injected from this source increment the .combinedSessionState idle
    // timer that apps like Microsoft Teams read, but do NOT reset the
    // .hidSystemState timer we use to detect real user input.
    @ObservationIgnored private let injectionSource = CGEventSource(stateID: .combinedSessionState)

    // F15 — has no default binding in macOS or common apps, so it's invisible
    // to whatever currently has focus.
    @ObservationIgnored private let virtualKey: CGKeyCode = 0x71

    /// Fires whenever `mode` or `showMenuBarIcon` changes, so imperative observers
    /// like the menu-bar status item can refresh. Mirrors `KeybindingStore.onBindingsChanged`.
    @ObservationIgnored var onStateChanged: (() -> Void)?

    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        static let isEnabled = "presence.isEnabled"
        static let idleThreshold = "presence.idleThreshold"
        static let preventSleep = "presence.preventSleep"
        static let showMenuBarIcon = "presence.showMenuBarIcon"
    }

    init(accessibility: AccessibilityService) {
        self.accessibility = accessibility
        let storedThreshold = defaults.double(forKey: Keys.idleThreshold)
        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
        self.idleThreshold = storedThreshold > 0 ? storedThreshold : 60
        self.preventSleep = defaults.bool(forKey: Keys.preventSleep)
        // Default the menu-bar icon on.
        if defaults.object(forKey: Keys.showMenuBarIcon) == nil {
            self.showMenuBarIcon = true
        } else {
            self.showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        }

        // Re-run the loop if Accessibility is granted/revoked while we're enabled.
        accessibility.onTrustChanged = { [weak self] _ in self?.reconcile() }
    }

    /// Re-applies persisted state that `didSet` can't act on during init (property
    /// observers don't fire for assignments in `init`). Call once after construction.
    func restore() {
        reconcile()
        if preventSleep { acquireSleepAssertion() }
    }

    /// Sets the user's intent and, if enabling while untrusted, prompts for
    /// Accessibility permission. The loop starts on its own once trust is granted.
    func setEnabled(_ on: Bool) {
        isEnabled = on
        if on && !accessibility.isTrusted {
            accessibility.requestTrust()
            accessibility.openAccessibilitySettings()
        }
    }

    /// Seconds since the last real user input. While the loop is running, uses our
    /// tracked value (which filters out our own injected events). Otherwise queries
    /// CG directly.
    func secondsSinceUserActivity() -> TimeInterval {
        switch mode {
        case .standby, .keepingAlive:
            return Date().timeIntervalSince(lastUserActivityAt)
        case .disabled, .needsPermission:
            let anyEventType = CGEventType(rawValue: ~0)!
            return CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyEventType)
        }
    }

    var statusDescription: String {
        switch mode {
        case .disabled: return "Paused"
        case .needsPermission: return "Needs Accessibility permission"
        case .standby: return "Standing by — you're using the Mac"
        case .keepingAlive: return "Keeping you 'Available'"
        }
    }

    /// SF Symbol for the presence status-bar item: hollow when off, a warning when
    /// enabled-but-not-permitted, dotted while standing by, filled while injecting.
    var menuBarSymbolName: String {
        switch mode {
        case .disabled: return "checkmark.circle"
        case .needsPermission: return "exclamationmark.circle"
        case .standby: return "checkmark.circle.dotted"
        case .keepingAlive: return "checkmark.circle.fill"
        }
    }

    /// Tooltip for the status-bar item, including the click affordance.
    var statusBarTooltip: String {
        switch mode {
        case .disabled: return "Keep me available is off — click to turn on"
        case .needsPermission: return "Keep me available needs Accessibility permission — click to grant"
        case .standby, .keepingAlive: return "\(statusDescription) — click to turn off"
        }
    }

    /// Starts or stops the keep-alive loop to match intent and trust.
    private func reconcile() {
        let shouldRun = isEnabled && accessibility.isTrusted
        if shouldRun {
            if timer == nil { startTimer() }
        } else {
            stopTimer()
            mode = isEnabled ? .needsPermission : .disabled
        }
    }

    private func startTimer() {
        lastUserActivityAt = Date()
        lastInjectionAt = nil
        mode = .standby
        let t = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let anyEventType = CGEventType(rawValue: ~0)!
        let hidIdle = CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: anyEventType)
        let now = Date()
        let lastHidEventAt = now.addingTimeInterval(-hidIdle)

        // Our injected events reset the HID idle counter too. If the most
        // recent HID event happened later than our last injection (beyond a
        // small grace), it was a real user input.
        let isUserEvent: Bool = {
            guard let lastInject = lastInjectionAt else { return true }
            return lastHidEventAt > lastInject.addingTimeInterval(injectionGrace)
        }()

        if isUserEvent {
            lastUserActivityAt = lastHidEventAt
        }

        let userIdle = now.timeIntervalSince(lastUserActivityAt)
        if userIdle >= idleThreshold {
            postKeepAliveEvent()
            lastInjectionAt = Date()
            mode = .keepingAlive
        } else {
            mode = .standby
        }
    }

    private func acquireSleepAssertion() {
        guard !hasSleepAssertion else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Control Center keeping Mac awake" as CFString,
            &id
        )
        if result == kIOReturnSuccess {
            sleepAssertionID = id
            hasSleepAssertion = true
        } else {
            preventSleep = false
        }
    }

    private func releaseSleepAssertion() {
        guard hasSleepAssertion else { return }
        IOPMAssertionRelease(sleepAssertionID)
        sleepAssertionID = 0
        hasSleepAssertion = false
    }

    private func postKeepAliveEvent() {
        guard let src = injectionSource else { return }
        let down = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
