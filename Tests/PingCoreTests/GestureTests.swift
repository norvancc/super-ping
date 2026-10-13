import CoreGraphics
import XCTest
@testable import PingCore

final class GestureTests: XCTestCase {
    func testDragPassesThroughAndHighlightsThenSends() {
        var gesture = Gesture()
        let origin = CGPoint(x: 500, y: 400)
        XCTAssertTrue(gesture.accept(.down, at: origin).swallow)
        let result = gesture.accept(.move, at: CGPoint(x: 360, y: 400))
        XCTAssertFalse(result.swallow, "Swallowing dragged events freezes the macOS cursor")
        XCTAssertEqual(result.effects, [.open(origin), .hover(.missing)])
        let release = gesture.accept(.up, at: CGPoint(x: 360, y: 400))
        XCTAssertEqual(release.effects, [.close, .send(.missing, origin)])
        XCTAssertTrue(release.swallow)
    }
    func testPendingThresholdAndPlainOptionClickReplay() {
        var gesture = Gesture()
        _ = gesture.accept(.down, at: .zero)
        XCTAssertTrue(gesture.accept(.move, at: CGPoint(x: 4, y: 0)).effects.isEmpty)
        XCTAssertEqual(gesture.accept(.up, at: .zero).effects, [.replayClick(.zero)])
    }
    func testCancelStillPassesDragAndConsumesPairedUp() {
        var gesture = Gesture()
        _ = gesture.accept(.down, at: .zero)
        _ = gesture.accept(.move, at: CGPoint(x: 140, y: 0))
        XCTAssertEqual(gesture.accept(.cancel, at: .zero).effects, [.close])
        XCTAssertFalse(gesture.accept(.move, at: CGPoint(x: 200, y: 0)).swallow)
        let up = gesture.accept(.up, at: CGPoint(x: 200, y: 0))
        XCTAssertTrue(up.swallow); XCTAssertTrue(up.effects.isEmpty)
        XCTAssertFalse(gesture.accept(.up, at: .zero).swallow)
    }
    func testCenterReleaseCancelsAndNoOptionPassesThrough() {
        var gesture = Gesture()
        XCTAssertFalse(gesture.accept(.down, at: .zero, option: false).swallow)
        _ = gesture.accept(.down, at: .zero)
        _ = gesture.accept(.move, at: CGPoint(x: 140, y: 0))
        XCTAssertEqual(gesture.accept(.move, at: CGPoint(x: 85, y: 0)).effects, [.hover(nil)])
        XCTAssertEqual(gesture.accept(.up, at: .zero).effects, [.close])
    }
    func testModifierReleaseDuringDragCancels() {
        var gesture = Gesture()
        _ = gesture.accept(.down, at: .zero)
        _ = gesture.accept(.move, at: CGPoint(x: 140, y: 0))
        let move = gesture.accept(.move, at: CGPoint(x: 150, y: 0), option: false)
        XCTAssertFalse(move.swallow); XCTAssertEqual(move.effects, [.close])
        XCTAssertTrue(gesture.accept(.up, at: CGPoint(x: 150, y: 0)).effects.isEmpty)
    }
    func testHighRateMovementOnlyPublishesSelectionChanges() {
        var gesture = Gesture()
        _ = gesture.accept(.down, at: .zero)
        var hovers = 0
        for i in 0..<1000 {
            let result = gesture.accept(.move, at: CGPoint(x: -140 - Double(i % 20), y: 0))
            XCTAssertFalse(result.swallow)
            hovers += result.effects.filter { if case .hover = $0 { return true }; return false }.count
        }
        XCTAssertEqual(hovers, 1)
        XCTAssertEqual(gesture.accept(.move, at: CGPoint(x: 140, y: 0)).effects, [.hover(.onMyWay)])
        XCTAssertEqual(gesture.accept(.up, at: CGPoint(x: 0, y: 140)).effects, [.close, .send(.danger, .zero)])
    }

}
