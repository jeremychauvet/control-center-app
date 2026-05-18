import ApplicationServices
import Foundation
import QuartzCore

/// Interpolates a window's frame from current to target over a short duration.
/// The Accessibility API has no animation primitive — it teleports — so this is a
/// best-effort tween driven by a 60fps timer. Some apps (Electron/Java/Qt) will
/// step rather than glide; that's expected and not worth hacking around.
@MainActor
final class WindowAnimator {
    private let controller: WindowControlling
    private var activeAnimation: Animation?

    init(controller: WindowControlling) {
        self.controller = controller
    }

    /// Animate `window` from its current frame to `target`. Passing duration <= 0
    /// (or a missing current frame) sets the frame instantly.
    func animate(_ window: AXUIElement, to target: CGRect, duration: TimeInterval) {
        // Cancel any in-flight animation on a different window — keeps things sane
        // if the user spams shortcuts.
        activeAnimation?.timer.invalidate()
        activeAnimation = nil

        guard duration > 0, let from = controller.frame(of: window) else {
            controller.setFrame(target, on: window)
            return
        }

        let animation = Animation(
            window: window,
            from: from,
            to: target,
            duration: duration,
            startTime: CACurrentMediaTime()
        )
        activeAnimation = animation

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, let current = self.activeAnimation, current === animation else {
                    timer.invalidate()
                    return
                }
                let elapsed = CACurrentMediaTime() - animation.startTime
                let progress = min(1.0, elapsed / animation.duration)
                let eased = Self.easeOutCubic(progress)
                let frame = Self.interpolate(from: animation.from, to: animation.to, t: eased)
                self.controller.setFrame(frame, on: animation.window)
                if progress >= 1.0 {
                    timer.invalidate()
                    self.activeAnimation = nil
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animation.timer = timer
    }

    private static func easeOutCubic(_ t: Double) -> Double {
        let inv = 1 - t
        return 1 - inv * inv * inv
    }

    private static func interpolate(from: CGRect, to: CGRect, t: Double) -> CGRect {
        CGRect(
            x: from.origin.x + (to.origin.x - from.origin.x) * t,
            y: from.origin.y + (to.origin.y - from.origin.y) * t,
            width:  from.width  + (to.width  - from.width)  * t,
            height: from.height + (to.height - from.height) * t
        )
    }

    private final class Animation {
        let window: AXUIElement
        let from: CGRect
        let to: CGRect
        let duration: CFTimeInterval
        let startTime: CFTimeInterval
        var timer: Timer = Timer()

        init(window: AXUIElement, from: CGRect, to: CGRect, duration: CFTimeInterval, startTime: CFTimeInterval) {
            self.window = window
            self.from = from
            self.to = to
            self.duration = duration
            self.startTime = startTime
        }
    }
}
