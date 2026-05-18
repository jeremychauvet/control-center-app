import AppKit
import Foundation

enum ScreenRegion {
    case leftHalf, rightHalf, topHalf, bottomHalf, maximize, center
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
        let axVisible = convertToAX(screen.visibleFrame)

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
        let primaryHeight = primaryScreenHeight
        return CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Convert an AX rect back to NSScreen coordinates.
    static func convertFromAX(_ rect: CGRect) -> CGRect {
        let primaryHeight = primaryScreenHeight
        return CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
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

    static func region(for action: WindowAction) -> ScreenRegion {
        switch action {
        case .leftHalf:   return .leftHalf
        case .rightHalf:  return .rightHalf
        case .topHalf:    return .topHalf
        case .bottomHalf: return .bottomHalf
        case .maximize:   return .maximize
        case .center:     return .center
        }
    }

    /// Height of the primary display — the screen whose origin is (0, 0). AX
    /// coordinates flip about this height.
    private static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? 0
    }
}
