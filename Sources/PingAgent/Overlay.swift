import AppKit
import PingCore

extension Ping {
    var color: NSColor {
        switch self {
        case .danger, .enemyVision: return NSColor(red: 1, green: 0.28, blue: 0.38, alpha: 1)
        case .push, .assist, .needVision: return NSColor(red: 0.27, green: 0.86, blue: 0.58, alpha: 1)
        case .onMyWay: return NSColor(red: 0.23, green: 0.63, blue: 1, alpha: 1)
        case .allIn, .missing: return NSColor(red: 1, green: 0.79, blue: 0.26, alpha: 1)
        }
    }
}

final class Overlay {
    private let panel: NSPanel
    private let canvas = WheelCanvas(frame: NSRect(x: 0, y: 0, width: 600, height: 600))
    private var timer: Timer?
    init() {
        panel = NSPanel(contentRect: canvas.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hasShadow = false
        panel.sharingType = .readOnly
        panel.level = .screenSaver; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = canvas
    }
    func wheel(at point: NSPoint) {
        hide(); canvas.pingOnly = nil; canvas.fixedAge = nil; canvas.selected = nil
        canvas.openedAt = Date(); position(at: point); panel.orderFrontRegardless(); animate()
    }
    func update(_ ping: Ping?) {
        guard canvas.selected != ping else { return }
        canvas.selected = ping
        if timer == nil { animate() }
    }
    func hide() { timer?.invalidate(); timer = nil; panel.orderOut(nil) }
    func flash(_ ping: Ping, at point: NSPoint) {
        hide(); canvas.fixedAge = nil; canvas.pingOnly = ping; canvas.openedAt = Date()
        position(at: point); panel.orderFrontRegardless(); animate()
    }
    func freezeForCapture() {
        timer?.invalidate(); timer = nil
        canvas.fixedAge = 0.4
        canvas.needsDisplay = true
        canvas.displayIfNeeded()
        panel.displayIfNeeded()
        panel.orderFrontRegardless()
    }
    private func animate() {
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.canvas.pingOnly == nil && !self.canvas.isWheelAnimating {
                self.timer?.invalidate(); self.timer = nil
                return
            }
            self.canvas.needsDisplay = true
            if self.canvas.pingOnly != nil && Date().timeIntervalSince(self.canvas.openedAt) >= 3.2 { self.hide() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func position(at point: NSPoint) {
        panel.setFrameOrigin(NSPoint(x: point.x - 300, y: point.y - 300)); canvas.needsDisplay = true
    }
}

/// Shared by the desktop overlay and the interactive preview; no second rendering path.
final class WheelCanvas: NSView {
    var selected: Ping? { didSet { if selected != oldValue { hoverAt = Date(); needsDisplay = true } } }
    var pingOnly: Ping?
    var fixedAge: Double?
    var openedAt = Date()
    private var hoverAt = Date()
    var isWheelAnimating: Bool {
        Date().timeIntervalSince(openedAt) < 0.15 || Date().timeIntervalSince(hoverAt) < 0.13
    }
    var interactive = false
    var onSelect: ((Ping) -> Void)?
    var onHover: ((Ping?) -> Void)?
    private var tracking: NSTrackingArea?
    override var acceptsFirstResponder: Bool { interactive }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area); tracking = area
    }
    private func track(_ event: NSEvent) {
        guard interactive else { return }
        let point = convert(event.locationInWindow, from: nil)
        let scale = min(bounds.width, bounds.height) / 600
        selected = CommandBuilder.selection(dx: (point.x - bounds.midX) / scale, dy: (point.y - bounds.midY) / scale)
        onHover?(selected)
    }
    override func mouseMoved(with event: NSEvent) { track(event) }
    override func mouseDragged(with event: NSEvent) { track(event) }
    override func mouseDown(with event: NSEvent) { track(event) }
    override func mouseUp(with event: NSEvent) { track(event); if let selected { onSelect?(selected) } }
    override func mouseExited(with event: NSEvent) { selected = nil; onHover?(nil) }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX, yBy: bounds.midY)
        let scale = min(bounds.width, bounds.height) / 600
        let age = fixedAge ?? Date().timeIntervalSince(openedAt)
        let intro = pingOnly == nil ? 0.85 + 0.15 * min(1, age / 0.12) : 1
        transform.scale(by: scale * intro); transform.concat()
        if let ping = pingOnly { drawEffect(ping, age: age); return }
        let inner: CGFloat = 86, outer: CGFloat = 188, ext: CGFloat = 288
        for index in 0..<8 where index % 2 == 0 {
            let mid = 90 - CGFloat(index) * 45
            let path = sector(inner: outer, outer: ext, start: mid - 22.5, end: mid + 22.5)
            radial(path, from: NSColor(white: 0.37, alpha: 0.36), to: NSColor(white: 0.37, alpha: 0), radius: ext)
        }
        radial(sector(inner: inner, outer: outer, start: 0, end: 360), from: NSColor(white: 0.16, alpha: 0.96), to: NSColor(white: 0.31, alpha: 0.92), radius: outer)
        for (index, ping) in Ping.allCases.enumerated() {
            let mid = 90 - CGFloat(index) * 45
            let hot = selected == ping
            if hot {
                let path = sector(inner: inner, outer: index % 2 == 0 ? ext : outer, start: mid - 22.5, end: mid + 22.5)
                radial(path, from: NSColor(white: 0.60, alpha: 0.55), to: NSColor(white: 0.63, alpha: index % 2 == 0 ? 0 : 0.50), radius: index % 2 == 0 ? ext : outer)
            }
            let line = NSBezierPath(); line.move(to: polar(inner, mid - 22.5)); line.line(to: polar(outer, mid - 22.5))
            NSColor(red: 0.63, green: 0.54, blue: 0.36, alpha: 0.45).setStroke(); line.lineWidth = 1.2; line.stroke()
            let amount = hot ? min(1, Date().timeIntervalSince(hoverAt) / 0.1) : 0
            drawPing(ping, center: polar(137, mid), size: 48 * (1 + 0.18 * amount), alpha: 1, muted: !hot)
        }
        let hub = NSBezierPath(ovalIn: NSRect(x: -inner, y: -inner, width: inner * 2, height: inner * 2))
        radial(hub, from: NSColor(red: 0.17, green: 0.36, blue: 0.38, alpha: 1), to: NSColor(red: 0.067, green: 0.16, blue: 0.17, alpha: 1), radius: inner)
        NSColor(red: 0.78, green: 0.67, blue: 0.43, alpha: 1).setStroke(); hub.lineWidth = 3; hub.stroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: -79, y: -79, width: 158, height: 158))
        NSColor(red: 0.54, green: 0.45, blue: 0.28, alpha: 0.6).setStroke(); ring.lineWidth = 1; ring.stroke()
        drawPing(.onMyWay, center: NSPoint(x: 0, y: 38), size: 36, alpha: 0.9, muted: true)
        drawText(selected?.title ?? "信号", center: .zero, size: 14, color: NSColor(red: 0.12, green: 0.66, blue: 0.88, alpha: 1))
        drawText("↖  BACK", center: NSPoint(x: 0, y: -47), size: 9, color: .gray)
    }
    private func drawEffect(_ ping: Ping, age: Double) {
        let life = CGFloat(max(0, min(1, (3.2 - age) / (3.2 * 0.13))))
        let ground = NSBezierPath(ovalIn: NSRect(x: -46, y: -35, width: 92, height: 26))
        ping.color.withAlphaComponent(life * 0.18).setFill(); ground.fill()
        for delay in [0.0, 0.22, 1.4] {
            let t = (age - delay) / 0.65
            guard t >= 0 && t <= 1 else { continue }
            let radius = CGFloat(60 * (0.25 + 1.1 * t))
            let ring = NSBezierPath(ovalIn: NSRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow(); shadow.shadowColor = ping.color.withAlphaComponent(0.65); shadow.shadowBlurRadius = 12; shadow.set()
            ping.color.withAlphaComponent(CGFloat(0.95 * (1 - t))).setStroke(); ring.lineWidth = 3; ring.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
        let pop: Double = age < 0.168 ? 0.4 + age / 0.168 * 0.75 : (age < 0.28 ? 1.15 - (age - 0.168) / 0.112 * 0.15 : 1)
        let bob = age > 0.3 ? 2.5 - 2.5 * cos((age - 0.3) * .pi * 2 / 1.6) : 0
        drawPing(ping, center: NSPoint(x: 0, y: 25 + bob), size: 110 * pop, alpha: life, muted: false)
    }
    private func sector(inner: CGFloat, outer: CGFloat, start: CGFloat, end: CGFloat) -> NSBezierPath {
        let path = NSBezierPath(); path.move(to: polar(inner, start)); path.line(to: polar(outer, start))
        path.appendArc(withCenter: .zero, radius: outer, startAngle: start, endAngle: end)
        path.line(to: polar(inner, end)); path.appendArc(withCenter: .zero, radius: inner, startAngle: end, endAngle: start, clockwise: true); path.close()
        return path
    }
    private func radial(_ path: NSBezierPath, from: NSColor, to: NSColor, radius: CGFloat) {
        NSGraphicsContext.saveGraphicsState(); path.addClip()
        NSGradient(starting: from, ending: to)?.draw(fromCenter: .zero, radius: 0, toCenter: .zero, radius: radius, options: [.drawsAfterEndingLocation])
        NSGraphicsContext.restoreGraphicsState()
    }
    private func polar(_ radius: CGFloat, _ degrees: CGFloat) -> NSPoint {
        NSPoint(x: cos(degrees * .pi / 180) * radius, y: sin(degrees * .pi / 180) * radius)
    }
    private func drawPing(_ ping: Ping, center: NSPoint, size: CGFloat, alpha: CGFloat, muted: Bool) {
        if let image = muted ? PingAssets.mutedImages[ping] : PingAssets.images[ping] {
            let ratio = min(size / image.size.width, size / image.size.height)
            let width = image.size.width * ratio, height = image.size.height * ratio
            image.draw(in: NSRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height), from: .zero, operation: .sourceOver, fraction: alpha)
        } else { drawText(ping.symbol, center: center, size: size * 0.8, color: ping.color.withAlphaComponent(alpha)) }
    }
    private func drawText(_ text: String, center: NSPoint, size: CGFloat, color: NSColor) {
        let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: color])
        let dimensions = string.size(); string.draw(at: NSPoint(x: center.x - dimensions.width / 2, y: center.y - dimensions.height / 2))
    }
}
