import AppKit
import PingCore

final class InputMonitor {
    var enabled = true { didSet { if !enabled { deliver(gesture.accept(.cancel, at: .zero)) } } }
    var onPress: ((NSPoint) -> Void)?
    var onStart: ((NSPoint) -> Void)?
    var onMove: ((Ping?) -> Void)?
    var onEnd: ((Ping?, NSPoint) -> Void)?
    var onCancel: (() -> Void)?
    var onToggle: (() -> Void)?
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
        let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .mouseMoved, .leftMouseUp, .rightMouseDown, .rightMouseUp, .keyDown, .keyUp, .flagsChanged]
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
        return connected
    }
    func stop() {
        deliver(gesture.accept(.cancel, at: .zero))
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }
    private func deliver(_ result: Gesture.Result) {
        // Keep the event-tap callback short. Drawing, sound loading and actions run after it returns.
        for effect in result.effects {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch effect {
                case .open(let point): self.onStart?(point); self.onEvent?("轮盘已打开")
                case .hover(let ping): self.onMove?(ping); self.onEvent?(ping.map { "选中：\($0.title)" } ?? "移回中心：取消")
                case .send(let ping, let point): self.onEnd?(ping, point); self.onEvent?("已发送：\(ping.title)")
                case .close: self.onCancel?()
                case .replayClick(let point): self.replayClick(at: point)
                }
            }
        }
    }
    private func replayClick(at point: CGPoint) {
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        let location = CGPoint(x: point.x, y: height - point.y)
        for type: CGEventType in [.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .left) else { continue }
            event.flags = .maskAlternate
            event.setIntegerValueField(.eventSourceUserData, value: selfMarker)
            event.setIntegerValueField(.mouseEventClickState, value: 1)
            event.post(tap: .cghidEventTap)
        }
    }
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if event.getIntegerValueField(.eventSourceUserData) == selfMarker { return false }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            deliver(gesture.accept(.cancel, at: .zero))
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        if (type == .mouseMoved || type == .leftMouseDragged) && !gesture.active { return false }
        // Use THIS event's location; NSEvent.mouseLocation can still be at the previous event.
        let point = CGPoint(x: event.location.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - event.location.y)
        let option = event.flags.contains(.maskAlternate)
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if type == .keyUp, swallowedKeys.remove(key) != nil { return true }
        if type == .keyDown && key == 35 && event.flags.contains([.maskAlternate, .maskControl]) {
            swallowedKeys.insert(key)
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { DispatchQueue.main.async { [weak self] in self?.onToggle?() } }
            return true
        }
        if type == .rightMouseUp && swallowRightUp { swallowRightUp = false; return true }
        if gesture.active && ((type == .keyDown && key == 53) || type == .rightMouseDown) {
            if type == .rightMouseDown { swallowRightUp = true } else { swallowedKeys.insert(key) }
            deliver(gesture.accept(.cancel, at: point)); return true
        }
        let input: Gesture.Event
        switch type {
        case .leftMouseDown: input = .down
        case .leftMouseDragged, .mouseMoved: input = .move
        case .leftMouseUp: input = .up
        case .flagsChanged where !option: input = .cancel
        default: return false
        }
        if type == .leftMouseDown && option && enabled {
            DispatchQueue.main.async { [weak self] in self?.onPress?(point) }
        }
        let result = gesture.accept(input, at: point, option: option, enabled: enabled)
        deliver(result)
        return result.swallow
    }
}
