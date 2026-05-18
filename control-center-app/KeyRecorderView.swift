import AppKit
import SwiftUI

/// SwiftUI control that captures a global-hotkey-style shortcut. Click to start
/// recording, then press the desired combo. Escape cancels. Pressing a key with
/// no modifiers beeps and is ignored (a pure letter can't be a global shortcut).
struct KeyRecorder: NSViewRepresentable {
    @Binding var combo: KeyCombo?

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.combo = combo
        view.onCapture = { captured in
            self.combo = captured
        }
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.combo = combo
    }
}

final class KeyRecorderNSView: NSView {
    var onCapture: ((KeyCombo) -> Void)?
    var combo: KeyCombo? {
        didSet { needsDisplay = true }
    }
    private var recording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func mouseDown(with event: NSEvent) {
        if recording {
            window?.makeFirstResponder(nil)
        } else {
            window?.makeFirstResponder(self)
        }
    }

    override func becomeFirstResponder() -> Bool {
        recording = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // escape
            window?.makeFirstResponder(nil)
            return
        }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.isEmpty else {
            NSSound.beep()
            return
        }
        let captured = KeyCombo(cocoaKeyCode: event.keyCode, cocoaModifiers: flags)
        onCapture?(captured)
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        let bg: NSColor = recording
            ? NSColor.controlAccentColor.withAlphaComponent(0.18)
            : NSColor.controlBackgroundColor
        bg.setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = recording ? 1.0 : 0.5
        path.stroke()

        let text = recording ? "Press shortcut\u{2026}" : (combo?.displayString ?? "—")
        let color: NSColor = recording ? .secondaryLabelColor : .labelColor
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color,
        ]
        let attr = NSAttributedString(string: text, attributes: attrs)
        let size = attr.size()
        let origin = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        attr.draw(at: origin)
    }
}
