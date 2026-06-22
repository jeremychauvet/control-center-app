import XCTest

/// Guards `WindowAction`'s contract: the case set is stable (its `rawValue`s are
/// UserDefaults persistence keys), every case has display metadata, and the
/// action→region mapping is intact.
final class WindowActionTests: XCTestCase {

    func testAllCasesPresent() {
        XCTAssertEqual(WindowAction.allCases.count, 7)
    }

    func testRawValuesAreStable() {
        // These rawValues key the persisted shortcut map (`bindings.v4`). Renaming
        // a case silently discards users' saved shortcuts — this is the guardrail.
        let expected: Set<String> = [
            "leftHalf", "rightHalf", "topHalf", "bottomHalf", "maximize", "center", "minimize",
        ]
        XCTAssertEqual(Set(WindowAction.allCases.map(\.rawValue)), expected)
        // rawValue == id, used as the SwiftUI ForEach identity.
        for action in WindowAction.allCases {
            XCTAssertEqual(action.id, action.rawValue)
        }
    }

    func testDisplayMetadataNonEmpty() {
        for action in WindowAction.allCases {
            XCTAssertFalse(action.displayName.isEmpty, "\(action) has no displayName")
            XCTAssertFalse(action.systemImage.isEmpty, "\(action) has no systemImage")
        }
    }

    func testRegionMapping() {
        if case .leftHalf = ScreenLayout.region(for: .leftHalf) {} else {
            XCTFail("leftHalf should map to .leftHalf region")
        }
        // .minimize isn't a frame action; region(for:) intentionally falls through to .center.
        if case .center = ScreenLayout.region(for: .minimize) {} else {
            XCTFail("minimize should fall through to .center region")
        }
    }
}
