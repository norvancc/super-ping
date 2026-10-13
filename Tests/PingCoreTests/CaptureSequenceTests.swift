import XCTest
@testable import PingCore

final class CaptureSequenceTests: XCTestCase {
    @MainActor
    func testCaptureOccursAfterVisiblePingAndCompositorWait() async throws {
        var events: [String] = []
        try await CaptureSequence.prepare(show: { events.append("show") }, freeze: { events.append("freeze") }, hide: { events.append("hide") }, sleep: { delay in
            events.append("wait:\(delay)")
        })
        events.append("capture")
        XCTAssertEqual(events, ["show", "wait:400000000", "freeze", "wait:180000000", "capture"])
    }
    @MainActor
    func testCancellationHidesPingAndPreventsCapture() async {
        var events: [String] = []
        do {
            try await CaptureSequence.prepare(show: { events.append("show") }, freeze: { events.append("freeze") }, hide: { events.append("hide") }, sleep: { _ in throw CancellationError() })
            events.append("capture")
            XCTFail("Should not capture after cancellation")
        } catch { }
        XCTAssertEqual(events, ["show", "hide"])
    }
}
