import XCTest
@testable import PingCore

final class ActionConfigurationTests: XCTestCase {
    func testExistingConfigurationKeepsCustomActionsAndPrompt() throws {
        let old = #"{"actions":{"missing":{"kind":"codexScreenshot","value":"","runInTerminal":true,"prompt":"My original question"},"danger":{"kind":"command","value":"echo test","runInTerminal":false,"prompt":""}},"sound":false,"codexExecutable":"/custom/codex","workingDirectory":"/tmp"}"#
        let config = try JSONDecoder().decode(Configuration.self, from: Data(old.utf8))
        XCTAssertEqual(config.action(for: .missing).prompt, "My original question")
        XCTAssertEqual(config.action(for: .danger).value, "echo test")
        XCTAssertFalse(config.sound)
        XCTAssertEqual(config.codexExecutable, "/custom/codex")
    }

    func testNewActionsSurviveSavingAndReloading() throws {
        for kind in ActionKind.allCases {
            var config = Configuration()
            var action = PingAction(kind: kind)
            action.value = "A name with 'quotes' / 空格\nsecond line"
            config.actions[Ping.missing.rawValue] = action
            let restored = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config))
            XCTAssertEqual(restored.action(for: .missing), action)
        }
    }

    func testAllScreenshotActionsUseMarkedCaptureWithoutRequiringCodexDirectory() {
        for kind in [ActionKind.screenshot, .screenshotClipboard, .screenshotPreview] {
            XCTAssertTrue(kind.requiresScreenshot)
            XCTAssertFalse(kind.requiresWorkingDirectory)
        }
        XCTAssertTrue(ActionKind.codexScreenshot.requiresScreenshot)
        XCTAssertTrue(ActionKind.codexScreenshot.requiresWorkingDirectory)
        XCTAssertFalse(ActionKind.copyText.requiresScreenshot)
    }

    func testWebActionRejectsExecutableSchemesAndMissingHosts() {
        for value in ["javascript:alert(1)", "file:///tmp/test", "https://", "example.com", "shortcuts://run-shortcut?name=test"] {
            XCTAssertNil(ActionInput.webURL(value))
        }
        XCTAssertEqual(ActionInput.webURL("  https://example.com/path?q=hello  ")?.absoluteString, "https://example.com/path?q=hello")
    }
}
