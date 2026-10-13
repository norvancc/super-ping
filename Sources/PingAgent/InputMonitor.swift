import AppKit
import PingCore

final class InputMonitor {
    var enabled = true { didSet { if !enabled { deliver(gesture.accept(.cancel, at: .zero)) } } }
    var options = Options() { didSet { if options != oldValue { deliver(gesture.accept(.cancel, at: .zero)) } } }
    var emoteMode = false
    var onMode: ((Bool) -> Void)?
    var capturingKey = false
    private var heldKeys = Set<UInt16>()
    private var heldButtons = Set<Int64>()
    private var replayFlags: CGEventFlags = []
    private var dragButton: Int64 = 0
    private var foreignKey = false
    private var lastMouseTime = ProcessInfo.processInfo.systemUptime
    private var watchdog: Timer?
    var onPress: ((NSPoint) -> Void)?
    var onStart: ((NSPoint) -> Void)?
    var onMove: ((Ping?) -> Void)?
    var onEnd: ((Ping?, NSPoint) -> Void)?
    var onCancel: (() -> Void)?
    var onToggle: (() -> Void)?
    var injectEvent: (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }
    var onEvent: ((String) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var gesture = Gesture()
    private var swallowRightUp = false
    private var swallowedKeys = Set<Int64>()
    private let selfMarker: Int64 = 0x50494E47
    var connected: Bool { tap.map { CFMachPortIsValid($0) && CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start() -> Bool {
        if connected { return true }
        stop()
        let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .mouseMoved, .leftMouseUp, .rightMouseDown, .rightMouseUp, .keyDown, .keyUp, .flagsChanged, .otherMouseDown, .otherMouseUp, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<InputMonitor>.fromOpaque(context).takeUnretainedValue()
            return monitor.handle(type, event) ? nil : Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = port
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        watchdog = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.gesture.active, ProcessInfo.processInfo.systemUptime - self.lastMouseTime > 10 else { return }
            self.deliver(self.gesture.accept(.cancel, at: .zero))
        }
        return connected
    }
    func stop() {
        deliver(gesture.accept(.cancel, at: .zero))
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil; watchdog?.invalidate(); watchdog = nil; foreignKey = false
        heldKeys.removeAll(); heldButtons.removeAll(); swallowedKeys.removeAll()
    }
    private func deliver(_ result: Gesture.Result) {
        // Keep the event-tap callback short. Drawing, sound loading and actions run after it returns.
        let button = dragButton, flags = replayFlags
        for effect in result.effects {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch effect {
                case .open(let point): self.onStart?(point); self.onEvent?("轮盘已打开")
                case .hover(let ping): self.onMove?(ping); self.onEvent?(ping.map { "选中：\($0.title)" } ?? "移回中心：取消")
                case .send(let ping, let point): self.onEnd?(ping, point); self.onEvent?("已发送：\(ping.title)")
                case .close: self.onCancel?()
                case .replayClick(let point): self.replayClick(at: point, button: button, flags: flags)
                case .replayDown(let point): self.replayClick(at: point, button: button, flags: flags, downOnly: true)
                }
            }
        }
    }
    private func replayClick(at point: CGPoint, button: Int64, flags: CGEventFlags, downOnly: Bool = false) {
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        let location = CGPoint(x: point.x, y: height - point.y)
        let down: CGEventType = button == 0 ? .leftMouseDown : .otherMouseDown
        let up: CGEventType = button == 0 ? .leftMouseUp : .otherMouseUp
        for type in downOnly ? [down] : [down, up] {
            guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .left) else { continue }
            event.setIntegerValueField(.mouseEventButtonNumber, value: button)
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: selfMarker)
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            injectEvent(event)
        }
    }
    func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if event.getIntegerValueField(.eventSourceUserData) == selfMarker { return false }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            deliver(gesture.accept(.cancel, at: .zero))
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        if (type == .mouseMoved || type == .leftMouseDragged) && !gesture.active { return false }
        // Use THIS event's location; NSEvent.mouseLocation can still be at the previous event.
        let point = CGPoint(x: event.location.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - event.location.y)
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        if type == .keyDown { heldKeys.insert(code) }
        if type == .keyUp { heldKeys.remove(code) }
        let button = event.getIntegerValueField(.mouseEventButtonNumber)
        if type == .otherMouseDown { heldButtons.insert(button) }
        if type == .otherMouseUp { heldButtons.remove(button) }
        func held(_ trigger: Trigger) -> Bool {
            switch trigger.kind {
            case "option": return event.flags.contains(.maskAlternate)
            case "control": return event.flags.contains(.maskControl)
            case "shift": return event.flags.contains(.maskShift)
            case "command": return event.flags.contains(.maskCommand)
            case "mouse4": return heldButtons.contains(3)
            case "mouse5": return heldButtons.contains(4)
            case "custom": return heldKeys.contains(trigger.keyCode)
            default: return false
            }
        }
        if capturingKey { return false }
        let isDown = type == .leftMouseDown || type == .otherMouseDown
        let isUp = type == .leftMouseUp || type == .otherMouseUp
        if isDown || isUp || type == .mouseMoved || type == .leftMouseDragged || type == .otherMouseDragged { lastMouseTime = ProcessInfo.processInfo.systemUptime }
        if !held(options.trigger) && !held(options.emoteTrigger) { foreignKey = false }
        let isCustom = [options.trigger, options.emoteTrigger].contains { $0.kind == "custom" && $0.keyCode == code }
        if type == .keyDown && !gesture.active && !isCustom && (held(options.trigger) || held(options.emoteTrigger)) { foreignKey = true }
        if isDown && !gesture.active {
            func claims(_ trigger: Trigger) -> Bool {
                if trigger.kind == "mouse4" { return button == 3 }
                if trigger.kind == "mouse5" { return button == 4 }
                return type == .leftMouseDown && held(trigger)
            }
            let ping = claims(options.trigger), emote = claims(options.emoteTrigger)
            guard ping != emote && !foreignKey && enabled else {
                if (type == .leftMouseDown ? 0 : button) == dragButton { _ = gesture.accept(.down, at: point, option: false) }
                return false
            }
            emoteMode = emote; dragButton = type == .leftMouseDown ? 0 : button
            gesture.wheel = emoteMode ? Ping.defaultWheel : options.wheel
            gesture.clickPing = emoteMode ? (options.emoteClick ? .generic : nil) : (options.clickPing ? options.clickPingID : nil)
            gesture.dragThreshold = options.dragThreshold
            replayFlags = event.flags
        }
        if isDown && gesture.active { return false }
        let owner = emoteMode ? options.emoteTrigger : options.trigger
        let side = owner.kind == "mouse4" || owner.kind == "mouse5"
        let option = side ? true : held(owner)
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp, swallowedKeys.remove(key) != nil {
            if !option { replayFlags = event.flags; deliver(gesture.accept(.triggerReleased, at: point)) }
            return true
        }
        let modifierMask: CGEventFlags = [.maskAlternate, .maskControl, .maskCommand, .maskShift]
        if type == .keyDown && code == options.hotkeyCode && event.flags.intersection(modifierMask).rawValue == options.hotkeyModifiers {
            swallowedKeys.insert(key)
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { DispatchQueue.main.async { [weak self] in self?.onToggle?() } }
            return true
        }
        if type == .keyDown || type == .keyUp {
            let isTrigger = [options.trigger, options.emoteTrigger].contains { $0.kind == "custom" && $0.keyCode == code }
            if isTrigger && enabled {
                if type == .keyDown { swallowedKeys.insert(key) }
                else if !option { replayFlags = event.flags; deliver(gesture.accept(.triggerReleased, at: point)) }
                return true
            }
        }
        if type == .rightMouseUp && swallowRightUp { swallowRightUp = false; return true }
        if gesture.active && ((type == .keyDown && key == 53) || type == .rightMouseDown) {
            if type == .rightMouseDown { swallowRightUp = true } else { swallowedKeys.insert(key) }
            deliver(gesture.accept(.cancel, at: point)); return true
        }
        let input: Gesture.Event
        switch type {
        case .leftMouseDown, .otherMouseDown:
            guard (type == .leftMouseDown ? 0 : button) == dragButton else { return false }; input = .down
        case .leftMouseDragged, .otherMouseDragged, .mouseMoved: input = .move
        case .leftMouseUp, .otherMouseUp:
            guard (type == .leftMouseUp ? 0 : button) == dragButton else { return false }; input = .up
        case .flagsChanged where !option: replayFlags = event.flags; input = .triggerReleased
        default: return false
        }
        if isDown && option && enabled {
            let mode = emoteMode
            DispatchQueue.main.async { [weak self] in self?.onMode?(mode); self?.onPress?(point) }
        }
        let result = gesture.accept(input, at: point, option: option, enabled: enabled)
        deliver(result)
        return result.swallow
    }
}
