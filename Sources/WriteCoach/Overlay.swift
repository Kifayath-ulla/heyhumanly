import SwiftUI
import AppKit
import QuartzCore

// MARK: - Overlay windows

/// Borderless panel that floats above the user's app and never takes keyboard focus.
class FloatingPanel: NSPanel {
    init(size: NSSize, rootView: AnyView) {
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let host = FirstMouseHostingView(rootView: rootView)
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        contentView = host
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that reacts to the first click even though the panel never becomes key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// An annotation placed exactly over a word in another app. Clicks pass through everywhere except the word itself.
final class UnderlinePanel: NSPanel {
    private let line: UnderlineView
    var isHighlighted = false { didSet { if oldValue != isHighlighted { line.highlighted = isHighlighted } } }
    var isDimmed = false { didSet { if oldValue != isDimmed { line.dimmed = isDimmed } } }

    init(color: NSColor, style: UnderlineView.Style, delay: Double, onClick: @escaping () -> Void, onHover: @escaping (Bool) -> Void) {
        line = UnderlineView(color: color, style: style, delay: delay, onClick: onClick, onHover: onHover)
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        contentView = line
    }
    override var canBecomeKey: Bool { false }

    func setStyle(_ style: UnderlineView.Style, color: NSColor) { line.update(style: style, color: color) }

    /// Covers the word plus a few points below it for the mark.
    func place(over word: CGRect) {
        let frame = NSRect(x: word.minX - 1, y: word.minY - 4, width: word.width + 2, height: word.height + 4)
        if self.frame != frame { setFrame(frame, display: true) }
        if !isVisible { orderFrontRegardless(); line.animateIn() }
    }
}

/// Draws the mark with Core Animation so it can "write itself" in.
final class UnderlineView: NSView {
    enum Style { case error, style }
    private(set) var color: NSColor
    private(set) var style: Style
    let delay: Double
    let onClick: () -> Void
    let onHover: (Bool) -> Void
    var highlighted = false { didSet { refreshFill() } }
    var dimmed = false { didSet { animateOpacity() } }
    private var hovering = false { didSet { refreshFill() } }
    private let stroke = CAShapeLayer()
    private let fill = CAShapeLayer()
    private var animated = false

    init(color: NSColor, style: Style, delay: Double, onClick: @escaping () -> Void, onHover: @escaping (Bool) -> Void) {
        self.color = color; self.style = style; self.delay = delay; self.onClick = onClick; self.onHover = onHover
        super.init(frame: .zero)
        wantsLayer = true
        layer?.addSublayer(fill)
        layer?.addSublayer(stroke)
        stroke.fillColor = nil
        stroke.lineCap = .round
        stroke.lineJoin = .round
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick() }

    func update(style: Style, color: NSColor) {
        guard style != self.style || color != self.color else { return }
        self.style = style; self.color = color
        rebuild()
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
    }
    override func cursorUpdate(with event: NSEvent) { NSCursor.pointingHand.set() }
    override func mouseEntered(with event: NSEvent) { hovering = true; onHover(true) }
    override func mouseExited(with event: NSEvent) { hovering = false; onHover(false) }

    override func layout() { super.layout(); rebuild() }

    private func rebuild() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        fill.frame = bounds; stroke.frame = bounds
        fill.path = CGPath(roundedRect: CGRect(x: 0, y: 3, width: bounds.width, height: max(0, bounds.height - 3)), cornerWidth: 3, cornerHeight: 3, transform: nil)
        let path = CGMutablePath()
        switch style {
        case .error:
            // Hand-drawn feeling wave: a little irregular, never mechanical.
            let y: CGFloat = 2.2, amp: CGFloat = 1.5, wave: CGFloat = 4.2
            var x: CGFloat = 1.5, up = true
            path.move(to: CGPoint(x: x, y: y))
            while x < bounds.width - 1.5 {
                let next = min(x + wave / 2, bounds.width - 1.5)
                path.addQuadCurve(to: CGPoint(x: next, y: y), control: CGPoint(x: (x + next) / 2, y: y + (up ? amp : -amp) * 1.6))
                x = next; up.toggle()
            }
            stroke.lineWidth = 1.6
            stroke.lineDashPattern = nil
        case .style:
            path.move(to: CGPoint(x: 1.5, y: 1.8)); path.addLine(to: CGPoint(x: bounds.width - 1.5, y: 1.8))
            stroke.lineWidth = 2
            stroke.lineDashPattern = [5, 3.5]
        }
        stroke.path = path
        stroke.strokeColor = color.cgColor
        CATransaction.commit()
        refreshFill()
    }

    private func refreshFill() {
        fill.fillColor = color.withAlphaComponent(highlighted ? 0.13 : hovering ? 0.10 : 0).cgColor
        stroke.lineWidth = (highlighted || hovering) ? (style == .error ? 2.0 : 2.4) : (style == .error ? 1.6 : 2)
    }

    private func animateOpacity() {
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = layer?.opacity; anim.toValue = dimmed ? 0.25 : 1; anim.duration = 0.2
        layer?.add(anim, forKey: "dim"); layer?.opacity = dimmed ? 0.25 : 1
    }

    /// The line draws itself from left to right, staggered across words.
    func animateIn() {
        guard !animated else { return }
        animated = true
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return }
        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0; draw.toValue = 1
        draw.duration = 0.38
        draw.beginTime = CACurrentMediaTime() + delay
        draw.fillMode = .backwards
        draw.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.7, 0.2, 1)
        stroke.add(draw, forKey: "draw")
    }
}
