import Carbon.HIToolbox
import Foundation
import Observation

/// Persists window-snap keybindings and animation settings in UserDefaults.
/// Observers (e.g. WindowManager) are notified via `onBindingsChanged` so that
/// hotkeys can be re-registered without a relaunch.
@Observable
final class KeybindingStore {
    private(set) var bindings: [WindowAction: KeyCombo]

    var animationEnabled: Bool {
        didSet { defaults.set(animationEnabled, forKey: Keys.animationEnabled) }
    }

    var animationDuration: Double {
        didSet { defaults.set(animationDuration, forKey: Keys.animationDuration) }
    }

    /// Called whenever `bindings` is mutated through this store. The WindowManager
    /// uses this to re-register Carbon hotkeys without a relaunch.
    @ObservationIgnored
    var onBindingsChanged: (() -> Void)?

    @ObservationIgnored
    private let defaults = UserDefaults.standard

    private enum Keys {
        // Bump on default-binding changes so existing prefs don't shadow new defaults.
        static let bindings = "bindings.v6"
        static let animationEnabled = "animationEnabled"
        static let animationDuration = "animationDuration"
    }

    init() {
        let stored: [String: KeyCombo] = defaults.data(forKey: Keys.bindings)
            .flatMap { try? JSONDecoder().decode([String: KeyCombo].self, from: $0) } ?? [:]
        var map: [WindowAction: KeyCombo] = [:]
        for (raw, combo) in stored {
            if let action = WindowAction(rawValue: raw) { map[action] = combo }
        }
        for action in WindowAction.allCases where map[action] == nil {
            map[action] = Self.defaultBindings[action]
        }
        self.bindings = map

        if defaults.object(forKey: Keys.animationEnabled) == nil {
            self.animationEnabled = true
        } else {
            self.animationEnabled = defaults.bool(forKey: Keys.animationEnabled)
        }
        let storedDuration = defaults.double(forKey: Keys.animationDuration)
        self.animationDuration = storedDuration > 0 ? storedDuration : 0.18
    }

    /// Defaults: Cmd+Up/Down for maximize/minimize, Cmd+Left/Right for the
    /// horizontal halves. Cmd+Shift+Left/Right are intentionally left unbound so
    /// macOS can use them to move the text cursor. Control+Option for the rest.
    /// Cmd+Down minimizes to the Dock; the bottom-half snap moves to Ctrl+Opt+Down
    /// to mirror top-half on Ctrl+Opt+Up.
    static let defaultBindings: [WindowAction: KeyCombo] = {
        let cmd = UInt32(cmdKey)
        let ctrlOpt = UInt32(controlKey | optionKey)
        return [
            .leftHalf:   KeyCombo(keyCode: UInt32(kVK_LeftArrow),  modifiers: cmd),
            .rightHalf:  KeyCombo(keyCode: UInt32(kVK_RightArrow), modifiers: cmd),
            .maximize:   KeyCombo(keyCode: UInt32(kVK_UpArrow),    modifiers: cmd),
            .minimize:   KeyCombo(keyCode: UInt32(kVK_DownArrow),  modifiers: cmd),
            .topHalf:    KeyCombo(keyCode: UInt32(kVK_UpArrow),    modifiers: ctrlOpt),
            .bottomHalf: KeyCombo(keyCode: UInt32(kVK_DownArrow),  modifiers: ctrlOpt),
            .center:     KeyCombo(keyCode: UInt32(kVK_ANSI_C),     modifiers: ctrlOpt),
        ]
    }()

    func setBinding(_ combo: KeyCombo, for action: WindowAction) {
        bindings[action] = combo
        persistBindings()
        onBindingsChanged?()
    }

    func resetToDefaults() {
        bindings = Self.defaultBindings
        persistBindings()
        onBindingsChanged?()
    }

    private func persistBindings() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(stringKeyed) {
            defaults.set(data, forKey: Keys.bindings)
        }
    }
}
