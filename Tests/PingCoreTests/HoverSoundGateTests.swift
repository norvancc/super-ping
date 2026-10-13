import XCTest
@testable import PingCore

final class HoverSoundGateTests: XCTestCase {
    func testRapidHoverDoesNotProduceAudioBacklog() {
        var gate = HoverSoundGate()
        var count = 0
        for i in 0..<1000 {
            if gate.accept(at: Double(i) / 1000) { count += 1 }
        }
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThanOrEqual(count, 16)
    }
    func testRejectedEventsDoNotPostponeNextSound() {
        var gate = HoverSoundGate()
        XCTAssertTrue(gate.accept(at: 0))
        XCTAssertFalse(gate.accept(at: 0.04))
        XCTAssertFalse(gate.accept(at: 0.06))
        XCTAssertTrue(gate.accept(at: 0.07))
        XCTAssertTrue(gate.accept(at: 1))
    }
}
