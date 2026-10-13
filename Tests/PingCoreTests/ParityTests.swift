import XCTest
@testable import PingCore

final class ParityTests: XCTestCase {
    func testPartialSettingsMigrationKeepsValuesAndDefaultsNewFields() throws {
        let data = Data(#"{"options":{"volume":23,"pingDuration":5.5,"clickPing":true},"actions":{"missing":{"kind":"copyText","value":"keep me","runInTerminal":false,"prompt":"custom"}}}"#.utf8)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        XCTAssertEqual(config.options.volume, 23)
        XCTAssertEqual(config.options.pingDuration, 5.5)
        XCTAssertTrue(config.options.clickPing)
        XCTAssertEqual(config.options.emoteWheel, EmoteDefinition.defaultWheel)
        XCTAssertEqual(config.action(for: .missing).value, "keep me")
    }
    func testMalformedOptionDoesNotResetOtherPreferences() throws {
        let options = try JSONDecoder().decode(Options.self, from: Data(#"{"volume":"bad","pingSize":175,"wheel":["missing"],"language":"en"}"#.utf8))
        XCTAssertEqual(options.volume, 70)
        XCTAssertEqual(options.pingSize, 175)
        XCTAssertEqual(options.language, "en")
        XCTAssertEqual(options.wheel, Ping.defaultWheel)
    }
    func testWheelSwapAndReplacementAreUnique() {
        let swapped = Options.placing(Ping.missing, in: Ping.defaultWheel, at: 0)
        XCTAssertEqual(swapped[0], .missing); XCTAssertEqual(swapped[6], .danger)
        let replaced = Options.placing(Ping.bait, in: swapped, at: 3)
        XCTAssertEqual(replaced[3], .bait); XCTAssertEqual(Set(replaced).count, 8)
    }
    func testCustomWheelDrivesGestureAndClickHasIndependentSelection() {
        var gesture = Gesture(); gesture.wheel = Options.placing(.visionCleared, in: Ping.defaultWheel, at: 0)
        gesture.clickPing = .bait; gesture.dragThreshold = 20
        _ = gesture.accept(.down, at: .zero)
        XCTAssertTrue(gesture.accept(.move, at: CGPoint(x: 0, y: 15)).effects.isEmpty)
        XCTAssertEqual(gesture.accept(.move, at: CGPoint(x: 0, y: 100)).effects, [.open(.zero), .hover(.visionCleared)])
        XCTAssertEqual(gesture.accept(.up, at: CGPoint(x: 0, y: 100)).effects, [.close, .send(.visionCleared, .zero)])
        _ = gesture.accept(.down, at: .zero)
        XCTAssertEqual(gesture.accept(.up, at: .zero).effects, [.send(.bait, .zero)])
    }
    func testReleasingTriggerBeforeClickReplaysDownOrSendsConfiguredClick() {
        var gesture = Gesture()
        _ = gesture.accept(.down, at: .zero)
        XCTAssertEqual(gesture.accept(.triggerReleased, at: .zero).effects, [.replayDown(.zero)])
        XCTAssertFalse(gesture.accept(.up, at: .zero, option: false).swallow)
        gesture.clickPing = .generic
        _ = gesture.accept(.down, at: .zero)
        XCTAssertEqual(gesture.accept(.triggerReleased, at: .zero).effects, [.send(.generic, .zero)])
        XCTAssertTrue(gesture.accept(.up, at: .zero, option: false).swallow)
    }
    func testDisabledPendingClickCannotSendOrReplay() {
        var gesture = Gesture(); gesture.clickPing = .bait
        _ = gesture.accept(.down, at: .zero)
        let result = gesture.accept(.up, at: .zero, enabled: false)
        XCTAssertTrue(result.swallow); XCTAssertEqual(result.effects, [.close])
    }
    func testRemovedEmoteRepairsAllReferences() {
        var options = Options()
        let item = CustomEmote(id: UUID().uuidString, name: "test", file: "test.image")
        options.customEmotes = [item]; options.emoteWheel[0] = item.id; options.clickEmote = item.id
        options.normalize(); XCTAssertEqual(options.emoteWheel[0], item.id)
        options.customEmotes = []; options.normalize()
        XCTAssertFalse(options.emoteWheel.contains(item.id)); XCTAssertEqual(Set(options.emoteWheel).count, 8)
        XCTAssertEqual(options.clickEmote, "facepalm")
    }
    func testConflictsAndInvalidHotkeyAreNormalized() {
        var options = Options(); options.emoteTrigger = options.trigger
        XCTAssertTrue(options.triggersClash); options.normalize(); XCTAssertEqual(options.emoteTrigger.kind, "off")
        options.emoteTrigger = Trigger("custom", keyCode: 35)
        XCTAssertTrue(options.triggersClash)
        options.hotkeyModifiers = 1 << 17; options.normalize()
        XCTAssertEqual(options.hotkeyModifiers, (1 << 18) | (1 << 19))
    }
    func testCatalogAndBounds() {
        XCTAssertEqual(Ping.allCases.count, 11); XCTAssertEqual(EmoteDefinition.catalog.count, 44)
        XCTAssertEqual(Set(EmoteDefinition.catalog.map(\.id)).count, 44)
        var options = Options(); options.pingDuration = 99; options.volume = -5; options.emoteSize = 900; options.normalize()
        XCTAssertEqual(options.pingDuration, 8); XCTAssertEqual(options.volume, 0); XCTAssertEqual(options.emoteSize, 300)
    }
    func testReleaseOrderingAndDigestValidation() {
        XCTAssertTrue(ReleaseVersion.isNewer("v0.10.0", than: "0.9.9"))
        XCTAssertFalse(ReleaseVersion.isNewer("0.7.0-beta", than: "0.6.0"))
        XCTAssertFalse(ReleaseVersion.isNewer("0.7.0", than: "0.7.0"))
        XCTAssertFalse(ReleaseVersion.isNewer("0.6.9", than: "0.7.0"))
        XCTAssertNil(ReleaseVersion.validDigest("sha256:bad"))
        XCTAssertEqual(ReleaseVersion.validDigest("sha256:" + String(repeating: "A", count: 64)), String(repeating: "a", count: 64))
    }
    func testAnimationCurveAndClashEndpoints() {
        XCTAssertEqual(AnimationTiming.cubic(0, 0, 0, 0.58, 1), 0, accuracy: 0.0001)
        XCTAssertEqual(AnimationTiming.cubic(1, 0, 0, 0.58, 1), 1, accuracy: 0.0001)
        XCTAssertGreaterThan(AnimationTiming.cubic(0.5, 0, 0, 0.58, 1), 0.5)
        XCTAssertEqual(AnimationTiming.shake(0.25), CGPoint(x: -3, y: 2))
        XCTAssertEqual(AnimationTiming.shake(1), .zero)
    }
}
