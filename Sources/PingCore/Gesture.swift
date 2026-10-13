import CoreGraphics
import Foundation

/// Pure gesture reducer; the event tap and regression tests use exactly this code.
public struct Gesture {
    public enum Event { case down, move, up, cancel }
    public enum Effect: Equatable {
        case open(CGPoint), hover(Ping?), send(Ping, CGPoint), close, replayClick(CGPoint)
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
    public init() {}
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
            if phase == .pending && hypot(point.x - origin.x, point.y - origin.y) > 8 {
                phase = .wheel; result.effects.append(.open(origin))
            }
            if phase == .wheel {
                let selection = CommandBuilder.selection(dx: point.x - origin.x, dy: point.y - origin.y)
                if !emittedHover || selection != lastHover {
                    result.effects.append(.hover(selection))
                    lastHover = selection; emittedHover = true
                }
            }
        case .up:
            guard phase != .idle else { return result }
            result.swallow = true
            if phase == .pending { result.effects = [.replayClick(origin)] }
            if phase == .wheel {
                result.effects = [.close]
                if option && enabled, let ping = CommandBuilder.selection(dx: point.x - origin.x, dy: point.y - origin.y) { result.effects.append(.send(ping, origin)) }
            }
            phase = .idle
        case .cancel:
            guard active else { return result }
            phase = .cancelled; result.effects = [.close]
        }
        return result
    }
}
