import AppKit
import Carbon
import Carbon.HIToolbox
import Foundation

/// A keyboard shortcut represented in Carbon terms (virtual key code + modifier mask),
/// which is what RegisterEventHotKey expects.
struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    /// Carbon virtual key code (e.g. kVK_LeftArrow).
    let keyCode: UInt32
    /// Carbon modifier mask (cmdKey | optionKey | controlKey | shiftKey).
    let modifiers: UInt32

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Build from an NSEvent-style key code + flags.
    init(cocoaKeyCode: UInt16, cocoaModifiers: NSEvent.ModifierFlags) {
        self.keyCode = UInt32(cocoaKeyCode)
        var mod: UInt32 = 0
        if cocoaModifiers.contains(.command) { mod |= UInt32(cmdKey) }
        if cocoaModifiers.contains(.option)  { mod |= UInt32(optionKey) }
        if cocoaModifiers.contains(.control) { mod |= UInt32(controlKey) }
        if cocoaModifiers.contains(.shift)   { mod |= UInt32(shiftKey) }
        self.modifiers = mod
    }

    var cocoaModifiers: NSEvent.ModifierFlags {
        var flags = NSEvent.ModifierFlags()
        if modifiers & UInt32(cmdKey)     != 0 { flags.insert(.command) }
        if modifiers & UInt32(optionKey)  != 0 { flags.insert(.option) }
        if modifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        if modifiers & UInt32(shiftKey)   != 0 { flags.insert(.shift) }
        return flags
    }

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("\u{2303}") } // ⌃
        if modifiers & UInt32(optionKey)  != 0 { parts.append("\u{2325}") } // ⌥
        if modifiers & UInt32(shiftKey)   != 0 { parts.append("\u{21E7}") } // ⇧
        if modifiers & UInt32(cmdKey)     != 0 { parts.append("\u{2318}") } // ⌘
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow:  return "\u{2190}"
        case kVK_RightArrow: return "\u{2192}"
        case kVK_UpArrow:    return "\u{2191}"
        case kVK_DownArrow:  return "\u{2193}"
        case kVK_Return:     return "\u{21A9}"
        case kVK_Tab:        return "\u{21E5}"
        case kVK_Space:      return "Space"
        case kVK_Escape:     return "\u{238B}"
        case kVK_Delete:     return "\u{232B}"
        case kVK_F1:  return "F1";  case kVK_F2:  return "F2"
        case kVK_F3:  return "F3";  case kVK_F4:  return "F4"
        case kVK_F5:  return "F5";  case kVK_F6:  return "F6"
        case kVK_F7:  return "F7";  case kVK_F8:  return "F8"
        case kVK_F9:  return "F9";  case kVK_F10: return "F10"
        case kVK_F11: return "F11"; case kVK_F12: return "F12"
        default:
            return translateToCharacter(keyCode: keyCode) ?? "?"
        }
    }

    private static func translateToCharacter(keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let data = unsafeBitCast(layoutPtr, to: CFData.self) as Data
        return data.withUnsafeBytes { rawPtr -> String? in
            guard let layout = rawPtr.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return nil
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var actualLength = 0
            let err = UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &actualLength,
                &chars
            )
            guard err == noErr, actualLength > 0 else { return nil }
            return String(utf16CodeUnits: chars, count: actualLength).uppercased()
        }
    }
}
