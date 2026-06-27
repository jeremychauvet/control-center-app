import Carbon.HIToolbox
import XCTest

/// Tests the fixed Activity Monitor shortcut definition: Control+Shift+Escape,
/// targeting Activity Monitor's bundle identifier.
final class SystemShortcutsServiceTests: XCTestCase {

    func testActivityMonitorComboIsControlShiftEscape() {
        let combo = SystemShortcutsService.activityMonitorCombo
        XCTAssertEqual(combo.keyCode, UInt32(kVK_Escape))
        XCTAssertEqual(combo.modifiers & UInt32(controlKey), UInt32(controlKey))
        XCTAssertEqual(combo.modifiers & UInt32(shiftKey), UInt32(shiftKey))
        // No other modifiers should be set.
        XCTAssertEqual(combo.modifiers & UInt32(cmdKey), 0)
        XCTAssertEqual(combo.modifiers & UInt32(optionKey), 0)
    }

    func testActivityMonitorComboDisplayString() {
        // ⌃ ⇧ then the Escape glyph ⎋ (order is fixed in KeyCombo.displayString).
        XCTAssertEqual(
            SystemShortcutsService.activityMonitorCombo.displayString,
            "\u{2303}\u{21E7}\u{238B}"
        )
    }

    func testActivityMonitorBundleID() {
        XCTAssertEqual(SystemShortcutsService.activityMonitorBundleID, "com.apple.ActivityMonitor")
    }

    func testLockScreenComboIsCommandK() {
        let combo = SystemShortcutsService.lockScreenCombo
        XCTAssertEqual(combo.keyCode, UInt32(kVK_ANSI_K))
        XCTAssertEqual(combo.modifiers & UInt32(cmdKey), UInt32(cmdKey))
        // Command only — no other modifiers.
        XCTAssertEqual(combo.modifiers & UInt32(controlKey), 0)
        XCTAssertEqual(combo.modifiers & UInt32(optionKey), 0)
        XCTAssertEqual(combo.modifiers & UInt32(shiftKey), 0)
    }

    func testLockScreenComboDisplayString() {
        // ⌘ then K.
        XCTAssertEqual(
            SystemShortcutsService.lockScreenCombo.displayString,
            "\u{2318}K"
        )
    }
}
