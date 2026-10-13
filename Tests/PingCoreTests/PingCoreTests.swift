import XCTest
@testable import PingCore

final class PingCoreTests: XCTestCase {
    func testWheelDirectionsAndCancellation() {
        XCTAssertNil(CommandBuilder.selection(dx: 20, dy: 0))
        XCTAssertEqual(CommandBuilder.selection(dx: 0, dy: 100), .danger)
        XCTAssertEqual(CommandBuilder.selection(dx: 100, dy: 100), .push)
        XCTAssertEqual(CommandBuilder.selection(dx: 100, dy: 0), .onMyWay)
        XCTAssertEqual(CommandBuilder.selection(dx: 100, dy: -100), .allIn)
        XCTAssertEqual(CommandBuilder.selection(dx: 0, dy: -100), .assist)
        XCTAssertEqual(CommandBuilder.selection(dx: -100, dy: -100), .needVision)
        XCTAssertEqual(CommandBuilder.selection(dx: -100, dy: 0), .missing)
        XCTAssertEqual(CommandBuilder.selection(dx: -100, dy: 100), .enemyVision)
    }
    func testDefaultAndConfigurationRoundTrip() throws {
        var config = Configuration()
        XCTAssertEqual(config.action(for: .missing).kind, .codexScreenshot)
        XCTAssertEqual(config.action(for: .missing).prompt, "What's this mean?")
        XCTAssertEqual(config.action(for: .danger).kind, .none)
        var action = PingAction(kind: .command)
        action.value = "printf 'hello'"; action.runInTerminal = false
        config.actions[Ping.danger.rawValue] = action
        let decoded = try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(config))
        XCTAssertEqual(decoded.action(for: .danger), action)
        XCTAssertEqual(decoded.action(for: .missing).kind, .codexScreenshot)
    }
    func testShellArgumentsRoundTripWithoutEvaluation() throws {
        let values = ["What's this mean?", "/tmp/a b'c.png", "$(echo INJECTED)`echo BAD`", "first\nsecond", "", "--help"]
        for value in values {
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", "printf %s " + CommandBuilder.quote(value)]
            let pipe = Pipe(); process.standardOutput = pipe
            try process.run()
            let output = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
            XCTAssertEqual(String(decoding: output, as: UTF8.self), value)
            XCTAssertEqual(process.terminationStatus, 0)
        }
    }
    func testCodexCommandPreservesImageAndPrompt() {
        XCTAssertEqual(CommandBuilder.codex(executable: "/a b/codex", image: "/tmp/a b.png", prompt: "What's this mean?", directory: "/a b"), "cd '/a b' && '/a b/codex' --image '/tmp/a b.png' -- 'What'\"'\"'s this mean?'")
    }
    func testCodexLaunchWithMockExecutable() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Ping test '\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let executable = folder.appendingPathComponent("mock codex")
        try Data("#!/bin/zsh\nprintf '%s\\0' \"$PWD\" \"$@\"\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let screenshot = folder.appendingPathComponent("screen ' shot.png").path
        let prompt = "What's this mean? $(echo should-not-run)"
        let command = CommandBuilder.codex(executable: executable.path, image: screenshot, prompt: prompt, directory: folder.path)
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        let pipe = Pipe(); process.standardOutput = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        let arguments = String(decoding: output, as: UTF8.self).split(separator: "\0").map(String.init)
        XCTAssertEqual(process.terminationStatus, 0)
        XCTAssertEqual(arguments, [folder.path, "--image", screenshot, "--", prompt])
    }
}
