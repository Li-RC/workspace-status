import AppKit

final class MenuStripView: NSView {
    var image: NSImage?
    var contentWidth: CGFloat = 1
    var click: ((NSPoint, TimeInterval) -> Void)?
    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    var scale: CGFloat { min(1, bounds.width / max(1, contentWidth)) }
    var contentOriginX: CGFloat { (bounds.width - contentWidth * scale) / 2 }

    override func draw(_ dirtyRect: NSRect) {
        guard let image, scale > 0 else { return }
        image.draw(in: NSRect(x: contentOriginX + 2 * scale, y: (bounds.height - 22 * scale) / 2,
                              width: image.size.width * scale, height: 22 * scale),
                   from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        click?(window.convertPoint(toScreen: event.locationInWindow), event.timestamp)
    }

    override func accessibilityPerformPress() -> Bool {
        guard let window, let click else { return false }
        click(NSPoint(x: window.frame.minX + contentOriginX + (contentWidth - 12) * scale, y: window.frame.midY),
              ProcessInfo.processInfo.systemUptime)
        return true
    }
}
