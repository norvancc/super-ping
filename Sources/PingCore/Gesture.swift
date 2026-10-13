import CoreGraphics
import Foundation

/// Pure gesture reducer; the event tap and regression tests use exactly this code.
public struct Gesture {
    public enum Event { case down, move, up, cancel, triggerReleased }
    public enum Effect: Equatable {
        case open(CGPoint), hover(Ping?), send(Ping, CGPoint), close, replayClick(CGPoint), replayDown(CGPoint)
    }
    public struct Result {
        public var swallow: Bool = false
        public var effects: [Effect] = []
    }
    private enum Phase { case idle, pending, wheel, cancelled }
    private var phase = Phase.idle
    private var origin = CGPoint.zero
    private var lastHover: Ping?
    private var emittedHover = false
    public var wheel = Ping.defaultWheel
    public var clickPing: Ping? = nil
    public var dragThreshold: Double = 8
    public init() {}
    private func selected(at point: CGPoint) -> Ping? {
        guard let token = CommandBuilder.selection(dx: point.x-origin.x, dy: point.y-origin.y),
              let index = Ping.defaultWheel.firstIndex(of: token), wheel.indices.contains(index) else { return nil }
        return wheel[index]
    }
    public var active: Bool { phase == .pending || phase == .wheel }
    public mutating func accept(_ event: Event, at point: CGPoint, option: Bool = true, enabled: Bool = true) -> Result {
        var result = Result()
        switch event {
        case .down:
            phase = .idle; emittedHover = false; lastHover = nil
            guard option && enabled else { return result }
            origin = point; phase = .pending; result.swallow = true
        case .move:
            // Never swallow movement: kCGSessionEventTap would freeze the visible cursor.
            guard active else { return result }
            guard option && enabled else { phase = .cancelled; result.effects = [.close]; return result }
            if phase == .pending && hypot(point.x - origin.x, point.y - origin.y) > dragThreshold {
                phase = .wheel; result.effects.append(.open(origin))
            }
            if phase == .wheel {
                let selection = selected(at: point)
                if !emittedHover || selection != lastHover {
                    result.effects.append(.hover(selection))
                    lastHover = selection; emittedHover = true
                }
            }
        case .up:
            guard phase != .idle else { return result }
            result.swallow = true
            if phase == .pending { result.effects = option && enabled ? (clickPing.map { [.send($0, origin)] } ?? [.replayClick(origin)]) : [.close] }
            if phase == .wheel {
                result.effects = [.close]
                if option && enabled, let ping = selected(at: point) { result.effects.append(.send(ping, origin)) }
            }
            phase = .idle
        case .triggerReleased:
            if phase == .pending {
                if let clickPing { result.effects = [.send(clickPing, origin)]; phase = .cancelled }
                else { result.effects = [.replayDown(origin)]; phase = .idle }
            } else if phase == .wheel { phase = .cancelled; result.effects = [.close] }
        case .cancel:
            guard active else { return result }
            phase = .cancelled; result.effects = [.close]
        }
        return result
    }
}
