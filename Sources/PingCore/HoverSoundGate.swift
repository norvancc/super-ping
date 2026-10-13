import Foundation

public struct HoverSoundGate {
    private var lastAccepted: TimeInterval?
    public init() {}
    public mutating func accept(at time: TimeInterval) -> Bool {
        if let lastAccepted, time - lastAccepted < 0.065 { return false }
        lastAccepted = time
        return true
    }
}
