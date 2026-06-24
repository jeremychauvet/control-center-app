import Foundation
import IOKit.pwr_mgt
import Observation

/// Holds an `IOPMAssertion` of type `kIOPMAssertionTypePreventUserIdleDisplaySleep`
/// while enabled, preventing the display from sleeping. No special permission is
/// required — this is independent of Presence's input-injection loop.
@MainActor
@Observable
final class KeepAwakeService {

    var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            if isEnabled { acquireAssertion() } else { releaseAssertion() }
        }
    }

    @ObservationIgnored private var assertionID: IOPMAssertionID = 0
    @ObservationIgnored private var hasAssertion = false

    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        // Legacy key — originally lived on PresenceService as `preventSleep`.
        // Kept as-is so existing users' toggle state survives the split.
        static let isEnabled = "presence.preventSleep"
    }

    init() {
        self.isEnabled = defaults.bool(forKey: Keys.isEnabled)
    }

    /// Re-applies persisted state that `didSet` can't act on during init
    /// (property observers don't fire for assignments in `init`). Call once
    /// after construction.
    func restore() {
        if isEnabled { acquireAssertion() }
    }

    private func acquireAssertion() {
        guard !hasAssertion else { return }
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Control Center keeping Mac awake" as CFString,
            &id
        )
        if result == kIOReturnSuccess {
            assertionID = id
            hasAssertion = true
        } else {
            isEnabled = false
        }
    }

    private func releaseAssertion() {
        guard hasAssertion else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        hasAssertion = false
    }
}
