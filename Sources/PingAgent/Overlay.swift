import AppKit
import PingCore

extension Ping {
    var color: NSColor {
        let hex: UInt32
        switch self {
        case .danger, .enemyVision: hex = 0xff3b55
        case .push: hex = 0x35d27a
        case .onMyWay, .generic: hex = 0x2e8bff
        case .allIn: hex = 0xf2b320
        case .assist, .needVision: hex = 0x56d43c
        case .missing: hex = 0xf2c518
        case .bait: hex = 0xefbc12
        case .visionCleared: hex = 0x2b80ff
        }
        return NSColor(red: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255, blue: CGFloat(hex & 255)/255, alpha: 1)
    }
}

final class Overlay {
    private let canvas = WheelCanvas(frame: NSRect(x: 0, y: 0, width: 600, height: 600))
    private lazy var panel = makePanel(canvas)
    private var timer: Timer?
    var options = Options()
    var emoteMode = false
    private struct Live { let panel: NSPanel; let canvas: WheelCanvas; let duration: Double }
    private var live: [Live] = []
    private weak var captureCanvas: WheelCanvas?
    private func makePanel(_ view: NSView) -> NSPanel {
        let p = NSPanel(contentRect: view.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.backgroundColor = .clear; p.isOpaque = false; p.hasShadow = false; p.sharingType = .readOnly
        p.level = .screenSaver; p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]; p.contentView = view
        return p
    }
    func wheel(at point: NSPoint) {
        hide(); canvas.pingOnly = nil; canvas.fixedAge = nil; canvas.selected = nil; canvas.options = options
        canvas.emoteWheel = emoteMode ? options.emoteWheel : nil
        canvas.openedAt = Date(); panel.setFrameOrigin(NSPoint(x: point.x-300, y: point.y-300)); panel.orderFrontRegardless(); animate()
    }
    func update(_ ping: Ping?) { if canvas.selected != ping { canvas.selected = ping; animate() } }
    func hide() { panel.orderOut(nil) }
    func hideCapture() {
        live.removeAll { item in
            if item.canvas === captureCanvas { item.panel.orderOut(nil); return true }
            return false
        }
        captureCanvas = nil
    }
    func flash(_ ping: Ping, at point: NSPoint) { spawn(ping: ping, emote: nil, at: point) }
    func emote(_ id: String, at point: NSPoint) {
        live.removeAll { item in if item.canvas.emoteOnly != nil { item.panel.orderOut(nil); return true }; return false }
        spawn(ping: nil, emote: id, at: point)
    }
    private func spawn(ping: Ping?, emote: String?, at point: NSPoint) {
        let view = WheelCanvas(frame: NSRect(x: 0, y: 0, width: 800, height: 800))
        view.effectCanvas = true; view.options = options; view.pingOnly = ping; view.emoteOnly = emote; view.openedAt = Date()
        let p = makePanel(view); p.setFrameOrigin(NSPoint(x: point.x-400, y: point.y-400)); p.orderFrontRegardless()
        if ping != nil, live.filter({ $0.canvas.pingOnly != nil }).count >= 60, let oldest = live.firstIndex(where: { $0.canvas.pingOnly != nil }) { live.remove(at: oldest).panel.orderOut(nil) }
        live.append(Live(panel: p, canvas: view, duration: emote == nil ? options.pingDuration : 3))
        if ping != nil { captureCanvas = view }
        animate()
    }
    func freezeForCapture() {
        captureCanvas?.fixedAge = 0.4; captureCanvas?.needsDisplay = true; captureCanvas?.displayIfNeeded()
        captureCanvas?.window?.displayIfNeeded()
    }
    private func animate() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.panel.isVisible && self.canvas.isWheelAnimating { self.canvas.needsDisplay = true }
            self.live.removeAll { item in
                if item.canvas.fixedAge == nil && Date().timeIntervalSince(item.canvas.openedAt) > item.duration + 0.15 { item.panel.orderOut(nil); return true }
                if item.canvas.fixedAge == nil { item.canvas.needsDisplay = true }
                return false
            }
            if self.live.isEmpty && (!self.panel.isVisible || !self.canvas.isWheelAnimating) { self.timer?.invalidate(); self.timer = nil }
        }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
}

/// Shared by the desktop overlay and the interactive preview; no second rendering path.
final class WheelCanvas: NSView {
    var options = Options()
    var emoteWheel: [String]?
    var emoteOnly: String?
    var effectCanvas = false
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
        let token = CommandBuilder.selection(dx: (point.x - bounds.midX) / scale, dy: (point.y - bounds.midY) / scale)
        selected = token.flatMap { p in Ping.defaultWheel.firstIndex(of: p).map { emoteWheel == nil ? options.wheel[$0] : Ping.defaultWheel[$0] } }
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
        let scale: CGFloat = effectCanvas ? 1 : min(bounds.width, bounds.height) / 600
        let age = fixedAge ?? Date().timeIntervalSince(openedAt)
        let intro = !effectCanvas ? 0.85 + 0.15 * AnimationTiming.cubic(age / 0.12, 0, 0, 0.58, 1) : 1
        transform.scale(by: scale * intro); transform.concat()
        if let id = emoteOnly { drawEmote(id, age: age); return }
        if let ping = pingOnly { drawEffect(ping, age: age); return }
        let inner: CGFloat = 86, outer: CGFloat = 188, ext: CGFloat = 288
        for index in 0..<8 where index % 2 == 0 {
            let mid = 90 - CGFloat(index) * 45
            let path = sector(inner: outer, outer: ext, start: mid - 22.5, end: mid + 22.5)
            radial(path, from: NSColor(white: 0.37, alpha: 0.36), to: NSColor(white: 0.37, alpha: 0), radius: ext)
        }
        radial(sector(inner: inner, outer: outer, start: 0, end: 360), from: NSColor(white: 0.16, alpha: 0.96), to: NSColor(white: 0.31, alpha: 0.92), radius: outer)
        for (index, ping) in (emoteWheel == nil ? options.wheel : Ping.defaultWheel).enumerated() {
            let mid = 90 - CGFloat(index) * 45
            let hot = selected == ping
            if hot {
                let path = sector(inner: inner, outer: index % 2 == 0 ? ext : outer, start: mid - 22.5, end: mid + 22.5)
                radial(path, from: NSColor(white: 0.60, alpha: 0.55), to: NSColor(white: 0.63, alpha: index % 2 == 0 ? 0 : 0.50), radius: index % 2 == 0 ? ext : outer)
            }
            let line = NSBezierPath(); line.move(to: polar(inner, mid - 22.5)); line.line(to: polar(outer, mid - 22.5))
            NSColor(red: 0.63, green: 0.54, blue: 0.36, alpha: 0.45).setStroke(); line.lineWidth = 1.2; line.stroke()
            let amount = hot ? min(1, Date().timeIntervalSince(hoverAt) / 0.1) : 0
            if let emotes = emoteWheel {
                drawEmoteIcon(emotes[index], center: polar(137, mid), size: 48 * (1 + 0.18 * amount))
            } else { drawPing(ping, center: polar(137, mid), size: 48 * (1 + 0.18 * amount), alpha: 1, muted: !hot) }
        }
        let hub = NSBezierPath(ovalIn: NSRect(x: -inner, y: -inner, width: inner * 2, height: inner * 2))
        radial(hub, from: NSColor(red: 0.17, green: 0.36, blue: 0.38, alpha: 1), to: NSColor(red: 0.067, green: 0.16, blue: 0.17, alpha: 1), radius: inner)
        NSColor(red: 0.78, green: 0.67, blue: 0.43, alpha: 1).setStroke(); hub.lineWidth = 3; hub.stroke()
        let ring = NSBezierPath(ovalIn: NSRect(x: -79, y: -79, width: 158, height: 158))
        NSColor(red: 0.54, green: 0.45, blue: 0.28, alpha: 0.6).setStroke(); ring.lineWidth = 1; ring.stroke()
        if emoteWheel != nil { drawEmoteIcon(options.clickEmote, center: NSPoint(x: 0, y: 38), size: 36) }
        else { drawPing(options.clickPingID, center: NSPoint(x: 0, y: 38), size: 36, alpha: 0.9, muted: true) }
        let label: String = emoteWheel != nil ? Localized.text("EMOTES", "表情") : Localized.text("PINGS", "信号")
        drawText(label, center: .zero, size: 15, color: NSColor(red: 0.12, green: 0.66, blue: 0.88, alpha: 1))
        drawText("↖  BACK", center: NSPoint(x: 0, y: -47), size: 9, color: .gray)
    }
    private func drawEmoteIcon(_ id: String, center: NSPoint, size: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        let rect = NSRect(x: center.x-size/2, y: center.y-size/2, width: size, height: size)
        NSBezierPath(ovalIn: rect).addClip()
        if let image = EmoteLibrary.shared.icon(id) { image.draw(in: rect) }
        else { drawText("?", center: center, size: size*0.6, color: .white) }
        NSGraphicsContext.restoreGraphicsState()
    }
    private func drawEmote(_ id: String, age: Double) {
        let bundled = EmoteDefinition.catalog.contains { $0.id == id }
        let size = CGFloat(options.emoteSize) * (bundled ? 1.25 : 1)
        let fade = bundled ? 1 : 1-AnimationTiming.cubic((age-2.65)/0.35,0.42,0,1,1)
        let pop = bundled ? 1 : (age < 0.15 ? 1.15*AnimationTiming.cubic(age/0.15,0,0,0.58,1) : (age < 0.25 ? 1.15-0.15*AnimationTiming.cubic((age-0.15)/0.1,0,0,0.58,1) : 1))
        let phase = age.truncatingRemainder(dividingBy:1.4)/1.4
        let bob = bundled ? 0 : (phase < 0.25 ? 4*AnimationTiming.cubic(phase/0.25,0.42,0,0.58,1) : phase < 0.75 ? 4-8*AnimationTiming.cubic((phase-0.25)/0.5,0.42,0,0.58,1) : -4+4*AnimationTiming.cubic((phase-0.75)/0.25,0.42,0,0.58,1))
        let side = size * pop * (bundled ? 1 : 0.85+0.15*fade)
        if let image = EmoteLibrary.shared.frame(id, age: age) {
            let ratio = min(side/max(1,image.size.width), side/max(1,image.size.height))
            let w = image.size.width*ratio, h = image.size.height*ratio
            image.draw(in: NSRect(x: -w/2, y: -h/2+bob, width: w, height: h), from: .zero, operation: .sourceOver, fraction: fade)
        } else { drawText("?", center: .zero, size: 80, color: .white) }
    }
    private func drawEffect(_ ping: Ping, age: Double) {
        let size = CGFloat(options.pingSize)
        let life = CGFloat(max(0, min(1, (options.pingDuration-age)/(options.pingDuration*0.13))))
        let f = age/options.pingDuration
        let groundAlpha = f < 0.1 ? AnimationTiming.cubic(f/0.1,0,0,0.58,1)*0.75 : (f < 0.85 ? 0.75-AnimationTiming.cubic((f-0.1)/0.75,0,0,0.58,1)*0.2 : (1-AnimationTiming.cubic((f-0.85)/0.15,0,0,0.58,1))*0.55)
        let ground = NSBezierPath(ovalIn: NSRect(x: -size*0.42, y: -size*0.44, width: size*0.84, height: size*0.24))
        NSGradient(starting: ping.color.withAlphaComponent(groundAlpha), ending: ping.color.withAlphaComponent(0))?.draw(in: ground, relativeCenterPosition: .zero)
        for delay in [0.0, 0.22, 1.4] {
            let t = (age-delay)/0.65; guard t >= 0 && t <= 1 else { continue }
            let eased = AnimationTiming.cubic(t, 0, 0, 0.58, 1)
            let radius = size*0.545*CGFloat(0.25+1.1*eased)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow(); shadow.shadowColor = ping.color.withAlphaComponent(0.7); shadow.shadowBlurRadius = 18; shadow.set()
            ping.color.withAlphaComponent(0.95*(1-eased)).setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: -radius, y: -radius, width: radius*2, height: radius*2)); ring.lineWidth = 3; ring.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
        let bobStart = ping == .allIn ? 0.5 : 0.3
        let phase = max(0,age-bobStart).truncatingRemainder(dividingBy:1.6)/0.8
        let bob = 5 * (phase < 1 ? AnimationTiming.cubic(phase,0.42,0,0.58,1) : 1-AnimationTiming.cubic(phase-1,0.42,0,0.58,1))
        if ping == .allIn {
            let slide = AnimationTiming.cubic(min(1,age/0.22),0.5,0,0.9,0.5)
            let shake = AnimationTiming.shake(max(0,age-0.22)/0.25)
            for (i,name) in ping.artwork.enumerated() {
                drawArt(name, center: NSPoint(x: (i == 0 ? 1 : -1)*size*0.64*(1-slide)+shake.x, y: size*0.23+size*0.64*(1-slide)+bob-shake.y), size: size, alpha: life*slide, color: ping.color)
            }
            let flash = (age-0.2)/0.35
            if flash >= 0 && flash <= 1 {
                let opacity = (flash < 0.3 ? AnimationTiming.cubic(flash/0.3,0,0,0.58,1) : 1-AnimationTiming.cubic((flash-0.3)/0.7,0,0,0.58,1))*life
                let radius = size*0.25*(0.3+1.9*AnimationTiming.cubic(flash,0,0,0.58,1))
                let path = NSBezierPath(ovalIn: NSRect(x:-radius,y:size*0.23-radius,width:radius*2,height:radius*2))
                NSGradient(starting:.white.withAlphaComponent(opacity),ending:ping.color.withAlphaComponent(0))?.draw(in:path,relativeCenterPosition:.zero)
            }
        } else {
            let first = age/0.168
            let pop = age < 0.168 ? 0.4+0.75*AnimationTiming.cubic(first,0.2,1.6,0.4,1) : (age < 0.28 ? 1.15-0.15*AnimationTiming.cubic((age-0.168)/0.112,0.2,1.6,0.4,1) : 1)
            drawArt(ping.artwork[0], center: NSPoint(x:0,y:size*0.23+bob), size:size*pop, alpha:life*min(1,AnimationTiming.cubic(age/0.168,0.2,1.6,0.4,1)),color:ping.color)
        }
    }
    private func drawArt(_ name: String, center: NSPoint, size: CGFloat, alpha: CGFloat, color: NSColor) {
        guard let image = PingAssets.textures[name] else { return }
        NSGraphicsContext.saveGraphicsState()
        let shadow=NSShadow();shadow.shadowColor=color.withAlphaComponent(alpha);shadow.shadowBlurRadius=10;shadow.set()
        image.draw(in:NSRect(x:center.x-size/2,y:center.y-size/2,width:size,height:size),from:.zero,operation:.sourceOver,fraction:alpha)
        NSGraphicsContext.restoreGraphicsState()
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
