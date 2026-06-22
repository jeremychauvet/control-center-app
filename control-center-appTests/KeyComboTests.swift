import Carbon.HIToolbox
import XCTest

/// Tests `KeyCombo` value semantics: Codable round-trip (it's persisted as JSON),
/// Cocoa↔Carbon modifier mapping, and display formatting.
final class KeyComboTests: XCTestCase {

    func testCodableRoundTrip() throws {
        let combo = KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(cmdKey))
        let data = try JSONEncoder().encode(combo)
        XCTAssertEqual(try JSONDecoder().decode(KeyCombo.self, from: data), combo)
    }

    func testCocoaModifierMappingRoundTrips() {
        let combo = KeyCombo(cocoaKeyCode: UInt16(kVK_ANSI_C), cocoaModifiers: [.command, .shift])
        XCTAssertEqual(combo.modifiers & UInt32(cmdKey), UInt32(cmdKey))
        XCTAssertEqual(combo.modifiers & UInt32(shiftKey), UInt32(shiftKey))
        XCTAssertEqual(combo.modifiers & UInt32(optionKey), 0)
        XCTAssertTrue(combo.cocoaModifiers.contains(.command))
        XCTAssertTrue(combo.cocoaModifiers.contains(.shift))
        XCTAssertFalse(combo.cocoaModifiers.contains(.option))
    }

    func testDisplayStringModifierOrderAndSymbols() {
        // Order is fixed: ⌃ ⌥ ⇧ ⌘ then the key.
        let mods = UInt32(controlKey | optionKey | shiftKey | cmdKey)
        let combo = KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifiers: mods)
        XCTAssertEqual(combo.displayString, "\u{2303}\u{2325}\u{21E7}\u{2318}\u{2190}")
    }

    func testDisplayStringSingleModifier() {
        let combo = KeyCombo(keyCode: UInt32(kVK_UpArrow), modifiers: UInt32(cmdKey))
        XCTAssertEqual(combo.displayString, "\u{2318}\u{2191}") // ⌘↑
    }

    func testKeyNameForArrowsAndFunctionKeys() {
        XCTAssertEqual(KeyCombo.keyName(for: UInt32(kVK_RightArrow)), "\u{2192}")
        XCTAssertEqual(KeyCombo.keyName(for: UInt32(kVK_DownArrow)), "\u{2193}")
        XCTAssertEqual(KeyCombo.keyName(for: UInt32(kVK_F5)), "F5")
        XCTAssertEqual(KeyCombo.keyName(for: UInt32(kVK_Space)), "Space")
    }
}
