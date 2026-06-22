import CoreGraphics
import XCTest

/// Tests the pure geometry in `ScreenLayout` — region frames, the NS↔AX
/// coordinate flip, and multi-display neighbor selection — without needing a
/// real `NSScreen`. `ScreenLayout.swift` is compiled into this test target.
final class ScreenLayoutTests: XCTestCase {

    /// A 1000×800 visible area at the AX origin (top-left).
    private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)

    // MARK: Region frames

    func testHalvesNoMargin() {
        XCTAssertEqual(ScreenLayout.regionFrame(for: .leftHalf, inAXVisible: visible),
                       CGRect(x: 0, y: 0, width: 500, height: 800))
        XCTAssertEqual(ScreenLayout.regionFrame(for: .rightHalf, inAXVisible: visible),
                       CGRect(x: 500, y: 0, width: 500, height: 800))
        XCTAssertEqual(ScreenLayout.regionFrame(for: .topHalf, inAXVisible: visible),
                       CGRect(x: 0, y: 0, width: 1000, height: 400))
        XCTAssertEqual(ScreenLayout.regionFrame(for: .bottomHalf, inAXVisible: visible),
                       CGRect(x: 0, y: 400, width: 1000, height: 400))
    }

    func testMaximizeFillsVisible() {
        XCTAssertEqual(ScreenLayout.regionFrame(for: .maximize, inAXVisible: visible), visible)
    }

    func testMarginInsetsEveryEdge() {
        // Left-half footprint (0,0,500,800) inset by 8 on all edges.
        XCTAssertEqual(ScreenLayout.regionFrame(for: .leftHalf, inAXVisible: visible, margin: 8),
                       CGRect(x: 8, y: 8, width: 484, height: 784))
    }

    func testCenterPreservesSizeAndCenters() {
        let current = CGRect(x: 123, y: 45, width: 400, height: 300)
        let f = ScreenLayout.regionFrame(for: .center, inAXVisible: visible, currentAXFrame: current)
        XCTAssertEqual(f, CGRect(x: 300, y: 250, width: 400, height: 300))
    }

    func testCenterClampsToVisibleMinusMargins() {
        let huge = CGRect(x: 0, y: 0, width: 5000, height: 5000)
        let f = ScreenLayout.regionFrame(for: .center, inAXVisible: visible, margin: 10, currentAXFrame: huge)
        XCTAssertEqual(f.width, 980)
        XCTAssertEqual(f.height, 780)
        XCTAssertEqual(f.midX, visible.midX, accuracy: 0.001)
        XCTAssertEqual(f.midY, visible.midY, accuracy: 0.001)
    }

    func testCenterDefaultsToHalfSizeWhenNoCurrentFrame() {
        let f = ScreenLayout.regionFrame(for: .center, inAXVisible: visible, currentAXFrame: nil)
        XCTAssertEqual(f.width, 500)
        XCTAssertEqual(f.height, 400)
    }

    // MARK: Coordinate conversion

    func testConvertIsInvolution() {
        let r = CGRect(x: 100, y: 200, width: 300, height: 150)
        let ax = ScreenLayout.convertToAX(r, primaryHeight: 1440)
        XCTAssertEqual(ScreenLayout.convertFromAX(ax, primaryHeight: 1440), r)
    }

    func testConvertKnownValue() {
        // NS rect at bottom (y=0, h=100) on a 900-tall primary → AX top y = 900-0-100.
        let ns = CGRect(x: 0, y: 0, width: 50, height: 100)
        XCTAssertEqual(ScreenLayout.convertToAX(ns, primaryHeight: 900),
                       CGRect(x: 0, y: 800, width: 50, height: 100))
    }

    // MARK: Neighbor selection (NSScreen coordinates; Y grows upward)

    func testNeighborRightAndNoneOnLeft() {
        let current = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        XCTAssertEqual(ScreenLayout.bestNeighborIndex(of: current, candidates: [right], direction: .right), 0)
        XCTAssertNil(ScreenLayout.bestNeighborIndex(of: current, candidates: [right], direction: .left))
    }

    func testNeighborPrefersLargerOverlap() {
        let current = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let smallOverlap = CGRect(x: 1000, y: 700, width: 500, height: 800) // y-overlap 100
        let bigOverlap   = CGRect(x: 1000, y: 0,   width: 500, height: 800) // y-overlap 800
        XCTAssertEqual(
            ScreenLayout.bestNeighborIndex(of: current, candidates: [smallOverlap, bigOverlap], direction: .right),
            1
        )
    }

    func testNeighborTieBrokenBySmallerGap() {
        let current = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let far  = CGRect(x: 1200, y: 0, width: 500, height: 800) // gap 200
        let near = CGRect(x: 1000, y: 0, width: 500, height: 800) // gap 0
        XCTAssertEqual(
            ScreenLayout.bestNeighborIndex(of: current, candidates: [far, near], direction: .right),
            1
        )
    }

    func testNeighborUpAndDown() {
        let current = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let above = CGRect(x: 0, y: 800,  width: 1000, height: 800)
        let below = CGRect(x: 0, y: -800, width: 1000, height: 800)
        XCTAssertEqual(ScreenLayout.bestNeighborIndex(of: current, candidates: [above, below], direction: .up), 0)
        XCTAssertEqual(ScreenLayout.bestNeighborIndex(of: current, candidates: [above, below], direction: .down), 1)
    }

    func testNoNeighborWithoutPerpendicularOverlap() {
        let current = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let disjoint = CGRect(x: 1000, y: 2000, width: 500, height: 500) // right but no Y overlap
        XCTAssertNil(ScreenLayout.bestNeighborIndex(of: current, candidates: [disjoint], direction: .right))
    }
}
