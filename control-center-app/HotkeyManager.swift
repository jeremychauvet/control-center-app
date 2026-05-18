import AppKit
import Carbon
import Carbon.HIToolbox
import Foundation

/// Registers global system-wide keyboard shortcuts via Carbon RegisterEventHotKey.
/// Carbon hotkeys survive focus loss and don't require event-tap accessibility.
@MainActor
final class HotkeyManager {
    private struct Registration {
        let id: UInt32
        let ref: EventHotKeyRef
        let handler: () -> Void
    }

    /// Carbon four-char signature ('SNPD') used to namespace our hotkeys.
    private static let signature: OSType = 0x534E5044

    private var registrations: [UInt32: Registration] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installEventHandler()
    }

    // HotkeyManager lives for the entire process lifetime, so deinit cleanup is
    // omitted on purpose — the OS reclaims hotkey registrations and the event
    // handler when the process exits. Removing this avoids a nonisolated-deinit
    // warning under Swift's approachable-concurrency mode.

    /// Register a global hotkey. Returns the assigned ID on success, nil on failure
    /// (commonly: another app already owns this combo).
    @discardableResult
    func register(combo: KeyCombo, handler: @escaping () -> Void) -> UInt32? {
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            NSLog("HotkeyManager: failed to register \(combo.displayString) status=\(status)")
            return nil
        }
        registrations[id] = Registration(id: id, ref: ref, handler: handler)
        return id
    }

    func unregister(id: UInt32) {
        guard let reg = registrations.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(reg.ref)
    }

    func unregisterAll() {
        for (_, reg) in registrations {
            UnregisterEventHotKey(reg.ref)
        }
        registrations.removeAll()
    }

    fileprivate func dispatch(id: UInt32) {
        registrations[id]?.handler()
    }

    private func installEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventSpec,
            selfPtr,
            &eventHandlerRef
        )
    }
}

/// C-convention event handler. Cannot capture context — receives `self` via userData.
private let hotkeyEventHandler: EventHandlerUPP = { _, eventRef, userData -> OSStatus in
    guard let eventRef, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    let id = hotKeyID.id
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            manager.dispatch(id: id)
        }
    }
    return noErr
}
