import AppKit
import Foundation

enum ScreenRegion {
    case leftHalf, rightHalf, topHalf, bottomHalf, maximize, center
}

enum ScreenDirection {
    case left, right, up, down
}

/// Pure functions for computing target window frames.
///
/// Coordinate spaces:
/// - `NSScreen` uses a bottom-left origin on the primary screen.
/// - Accessibility (AX) APIs use a top-left origin on the primary screen.
///
/// All "target" frames returned here are in AX coordinates so the caller can hand
/// them straight to AXUIElementSetAttributeValue.
enum ScreenLayout {

    /// Compute the target frame (AX coordinates) for the given region on `screen`.
    ///
    /// - Parameter margin: Inset applied to every edge of the region's footprint.
    ///   Two adjacent regions (e.g. left + right half) end up separated by `2 * margin`,
    ///   matching macOS native tiling appearance when "Tiled windows have margins"
    ///   is enabled in System Settings.
    /// - Parameter currentAXFrame: Used by `.center` to preserve the window's size.
    static func targetFrame(
        for region: ScreenRegion,
        on screen: NSScreen,
        margin: CGFloat = 0,
        currentAXFrame: CGRect? = nil
    ) -> CGRect {
        // visibleFrame excludes the menu bar and Dock — exactly what we want.
        regionFrame(
            for: region,
            inAXVisible: convertToAX(screen.visibleFrame),
            margin: margin,
            currentAXFrame: currentAXFrame
        )
    }

    /// Pure region math on an already-AX-converted visible rect. Split out from
    /// `targetFrame` so the geometry is unit-testable without an `NSScreen`.
    static func regionFrame(
        for region: ScreenRegion,
        inAXVisible axVisible: CGRect,
        margin: CGFloat = 0,
        currentAXFrame: CGRect? = nil
    ) -> CGRect {
        func inset(_ rect: CGRect) -> CGRect {
            guard margin > 0 else { return rect }
            return rect.insetBy(dx: margin, dy: margin)
        }

        switch region {
        case .leftHalf:
            return inset(CGRect(
                x: axVisible.minX, y: axVisible.minY,
                width: axVisible.width / 2, height: axVisible.height
            ))
        case .rightHalf:
            return inset(CGRect(
                x: axVisible.minX + axVisible.width / 2, y: axVisible.minY,
                width: axVisible.width / 2, height: axVisible.height
            ))
        case .topHalf:
            return inset(CGRect(
                x: axVisible.minX, y: axVisible.minY,
                width: axVisible.width, height: axVisible.height / 2
            ))
        case .bottomHalf:
            return inset(CGRect(
                x: axVisible.minX, y: axVisible.minY + axVisible.height / 2,
                width: axVisible.width, height: axVisible.height / 2
            ))
        case .maximize:
            return inset(axVisible)
        case .center:
            let size = currentAXFrame?.size
                ?? CGSize(width: axVisible.width / 2, height: axVisible.height / 2)
            let maxW = max(0, axVisible.width  - 2 * margin)
            let maxH = max(0, axVisible.height - 2 * margin)
            let w = min(size.width,  maxW)
            let h = min(size.height, maxH)
            return CGRect(
                x: axVisible.minX + (axVisible.width  - w) / 2,
                y: axVisible.minY + (axVisible.height - h) / 2,
                width: w, height: h
            )
        }
    }

    /// Convert an NSRect (NSScreen bottom-left, primary-origin) to AX coordinates.
    static func convertToAX(_ rect: CGRect) -> CGRect {
        convertToAX(rect, primaryHeight: primaryScreenHeight)
    }

    /// Convert an AX rect back to NSScreen coordinates.
    static func convertFromAX(_ rect: CGRect) -> CGRect {
        convertFromAX(rect, primaryHeight: primaryScreenHeight)
    }

    /// The flip is its own involution, so one helper serves both directions. The
    /// `primaryHeight` parameter makes it testable without reading `NSScreen`.
    static func convertToAX(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    static func convertFromAX(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        convertToAX(rect, primaryHeight: primaryHeight)
    }

    /// Find the NSScreen that best contains the given AX-coordinate frame. Falls back
    /// to the main screen if no screen contains the frame's center (e.g. after a
    /// monitor was unplugged).
    static func screen(forAXFrame frame: CGRect) -> NSScreen? {
        let primaryHeight = primaryScreenHeight
        let axCenter = CGPoint(x: frame.midX, y: frame.midY)
        let nsCenter = CGPoint(x: axCenter.x, y: primaryHeight - axCenter.y)
        return NSScreen.screens.first { $0.frame.contains(nsCenter) }
            ?? NSScreen.main
    }

    /// Maps frame-based actions to their region. `.minimize` is not a frame
    /// action and is handled separately upstream, so it intentionally falls
    /// through to `.center` here — callers must not reach this with `.minimize`.
    static func region(for action: WindowAction) -> ScreenRegion {
        switch action {
        case .leftHalf:   return .leftHalf
        case .rightHalf:  return .rightHalf
        case .topHalf:    return .topHalf
        case .bottomHalf: return .bottomHalf
        case .maximize:   return .maximize
        case .center:     return .center
        case .minimize:   return .center
        }
    }

    /// Find the screen that sits adjacent to `screen` in the given physical
    /// direction, based on the current Display Arrangement. Returns nil if no
    /// screen lies on that side. Works with any layout (edge-to-edge, stacked,
    /// staggered) because it operates on the actual NSScreen frames.
    ///
    /// Candidates must (a) be entirely past the corresponding edge of `screen`
    /// and (b) share some perpendicular-axis overlap with it. Among valid
    /// candidates, the one with the largest overlap wins; ties are broken by
    /// shortest gap.
    static func neighborScreen(of screen: NSScreen, direction: ScreenDirection) -> NSScreen? {
        let others = NSScreen.screens.filter { $0 !== screen }
        guard let index = bestNeighborIndex(
            of: screen.frame,
            candidates: others.map(\.frame),
            direction: direction
        ) else {
            return nil
        }
        return others[index]
    }

    /// Pure neighbor selection over plain frames (NSScreen coordinates, Y grows
    /// upward). Returns the index in `candidates` of the screen adjacent to
    /// `current` in `direction`, or nil if none qualifies. A candidate must be
    /// entirely past the corresponding edge of `current` and share some
    /// perpendicular-axis overlap; the largest overlap wins, ties broken by the
    /// smaller gap. Extracted from `neighborScreen` so it can be tested with
    /// synthetic arrangements.
    ///
    /// - Parameter slack: tolerance (default 1pt) so screens that are nominally
    ///   edge-to-edge but off by a hair still register as neighbors.
    static func bestNeighborIndex(
        of current: CGRect,
        candidates: [CGRect],
        direction: ScreenDirection,
        slack: CGFloat = 1
    ) -> Int? {
        var best: (index: Int, overlap: CGFloat, gap: CGFloat)?

        for (index, f) in candidates.enumerated() {
            let overlap: CGFloat
            let gap: CGFloat
            switch direction {
            case .left:
                guard f.maxX <= current.minX + slack else { continue }
                overlap = max(0, min(current.maxY, f.maxY) - max(current.minY, f.minY))
                gap = current.minX - f.maxX
            case .right:
                guard f.minX >= current.maxX - slack else { continue }
                overlap = max(0, min(current.maxY, f.maxY) - max(current.minY, f.minY))
                gap = f.minX - current.maxX
            case .up:
                // NSScreen Y grows upward, so a higher screen has a greater minY.
                guard f.minY >= current.maxY - slack else { continue }
                overlap = max(0, min(current.maxX, f.maxX) - max(current.minX, f.minX))
                gap = f.minY - current.maxY
            case .down:
                guard f.maxY <= current.minY + slack else { continue }
                overlap = max(0, min(current.maxX, f.maxX) - max(current.minX, f.minX))
                gap = current.minY - f.maxY
            }
            guard overlap > 0 else { continue }
            if let b = best {
                if overlap > b.overlap || (overlap == b.overlap && gap < b.gap) {
                    best = (index, overlap, gap)
                }
            } else {
                best = (index, overlap, gap)
            }
        }

        return best?.index
    }

    /// Height of the primary display — the screen whose origin is (0, 0). AX
    /// coordinates flip about this height.
    private static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? 0
    }
}
