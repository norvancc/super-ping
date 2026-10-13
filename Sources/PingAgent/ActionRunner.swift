import AppKit
import CoreGraphics
import PingCore

struct ActionFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@MainActor
final class ActionRunner {
    let store: Store
    private var busy = false
    init(store: Store) { self.store = store }

    func run(_ ping: Ping, at point: NSPoint, prepareScreenshot: (() async throws -> Void)? = nil, finishScreenshot: (() -> Void)? = nil, captureOnly: Bool = false, contextTask: Task<PingContext, Never>? = nil) {
        guard !busy else { store.status = "上一个动作仍在执行，请稍候。"; return }
        let action = captureOnly ? PingAction(kind: .codexScreenshot) : store.configuration.action(for: ping)
        guard action.kind != .none else { return }
        busy = true
        Task {
            defer { busy = false }
            do {
                try await execute(action, ping: ping, point: point, prepareScreenshot: prepareScreenshot, finishScreenshot: finishScreenshot, captureOnly: captureOnly, contextTask: contextTask)
                store.status = "已执行：\(ping.title) → \(action.kind.title)"
            } catch {
                store.status = error.localizedDescription
                let alert = NSAlert()
                alert.messageText = "Ping 动作未完成"
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: "好")
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }

    private func execute(_ action: PingAction, ping: Ping, point: NSPoint, prepareScreenshot: (() async throws -> Void)?, finishScreenshot: (() -> Void)?, captureOnly: Bool, contextTask: Task<PingContext, Never>?) async throws {
        let config = store.configuration
        let workingDirectory = (config.workingDirectory as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        if action.kind.requiresWorkingDirectory && !captureOnly && !(FileManager.default.fileExists(atPath: workingDirectory, isDirectory: &isDirectory) && isDirectory.boolValue) {
            throw ActionFailure(message: "工作目录不存在，请在设置中选择有效文件夹。")
        }
        switch action.kind {
        case .none: break
        case .application:
            let value = (action.value as NSString).expandingTildeInPath
            guard !value.isEmpty else { throw ActionFailure(message: "请先选择要打开的应用。") }
            let url = value.hasPrefix("/") ? URL(fileURLWithPath: value) : NSWorkspace.shared.urlForApplication(withBundleIdentifier: value)
            guard let url, FileManager.default.fileExists(atPath: url.path) else { throw ActionFailure(message: "找不到应用：\(value)") }
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        case .openURL:
            guard let url = ActionInput.webURL(action.value) else { throw ActionFailure(message: "请填写完整的 http:// 或 https:// 网页地址。") }
            guard NSWorkspace.shared.open(url) else { throw ActionFailure(message: "无法打开网页。请检查默认浏览器。") }
        case .openFile:
            let value = (action.value as NSString).expandingTildeInPath
            guard !value.isEmpty, FileManager.default.fileExists(atPath: value) else { throw ActionFailure(message: "文件或文件夹不存在。") }
            guard NSWorkspace.shared.open(URL(fileURLWithPath: value)) else { throw ActionFailure(message: "无法打开该文件或文件夹。") }
        case .shortcut:
            let name = action.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw ActionFailure(message: "请填写快捷指令的名称。") }
            _ = try await process("/usr/bin/shortcuts", ["run", name])
        case .copyText:
            guard !action.value.isEmpty else { throw ActionFailure(message: "请填写要复制的文字。") }
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(action.value, forType: .string) else { throw ActionFailure(message: "无法写入剪贴板，请重试。") }
        case .codexScreenshot, .screenshot, .screenshotClipboard, .screenshotPreview:
            guard CGPreflightScreenCaptureAccess() else {
                CGRequestScreenCaptureAccess()
                throw ActionFailure(message: "请在系统设置 → 隐私与安全性 → 屏幕录制中允许 Super Ping，然后重新启动应用再试。")
            }
            // Wait for the visible ping FIRST; only then capture the current desktop.
            guard let prepareScreenshot else { throw ActionFailure(message: "截图显示流程未就绪，已停止发送。") }
            store.status = "正在等待实际 Ping 动画展开并截图…"
            var screenshotFinished = false
            defer { if !screenshotFinished { finishScreenshot?() } }
            try await prepareScreenshot()
            let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
            guard let screen, let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                  let image = CGDisplayCreateImage(number.uint32Value) else {
                throw ActionFailure(message: "无法截取屏幕。请检查屏幕录制权限。")
            }
            let folder = store.directory.appendingPathComponent("Screenshots", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let path = folder.appendingPathComponent("ping-\(UUID().uuidString).png")
            guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
                throw ActionFailure(message: "截图编码失败，已停止发送。")
            }
            try data.write(to: path, options: .atomic)
            finishScreenshot?(); screenshotFinished = true
            if !captureOnly && action.kind != .codexScreenshot {
                switch action.kind {
                case .screenshotClipboard:
                    NSPasteboard.general.clearContents()
                    guard NSPasteboard.general.writeObjects([NSImage(cgImage: image, size: .zero)]) else { throw ActionFailure(message: "截图已保存，但无法复制到剪贴板。") }
                case .screenshotPreview:
                    guard NSWorkspace.shared.open(path) else { throw ActionFailure(message: "截图已保存，但无法打开预览。") }
                default: break
                }
                return
            }
            let context = await contextTask?.value
            let prompt = context?.prompt(action.prompt) ?? action.prompt
            try Data(prompt.utf8).write(to: path.deletingPathExtension().appendingPathExtension("txt"), options: .atomic)
            if captureOnly {
                NSWorkspace.shared.open(path)
                return
            }
            let executable = (config.codexExecutable as NSString).expandingTildeInPath
            guard !executable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ActionFailure(message: "请填写 Codex 可执行文件路径。") }
            let command = CommandBuilder.codex(executable: executable, image: path.path, prompt: prompt, directory: workingDirectory)
            try await terminal(command)
        case .script, .command:
            guard !action.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ActionFailure(message: "请先填写脚本路径或命令。") }
            var command = action.value
            if action.kind == .script {
                let path = (action.value as NSString).expandingTildeInPath
                guard FileManager.default.fileExists(atPath: path) else { throw ActionFailure(message: "脚本文件不存在：\(path)") }
                let interpreter: String
                switch URL(fileURLWithPath: path).pathExtension.lowercased() {
                case "scpt", "applescript": interpreter = "/usr/bin/osascript "
                case "sh", "zsh": interpreter = "/bin/zsh "
                case "bash": interpreter = "/bin/bash "
                default:
                    guard FileManager.default.isExecutableFile(atPath: path) else { throw ActionFailure(message: "此脚本需要可执行权限及 shebang；也可使用“执行 Mac 命令”指定解释器。") }
                    interpreter = ""
                }
                command = interpreter + CommandBuilder.quote(path)
            }
            let prefix = "export PING_KIND=" + CommandBuilder.quote(ping.rawValue) + "; export PING_X=" + CommandBuilder.quote(String(Double(point.x))) + "; export PING_Y=" + CommandBuilder.quote(String(Double(point.y))) + "; "
            if action.runInTerminal {
                try await terminal("cd " + CommandBuilder.quote(workingDirectory) + " || exit; " + prefix + "\n" + command)
            } else {
                _ = try await process("/bin/zsh", ["-lc", prefix + "\n" + command], directory: workingDirectory)
            }
        }
    }

    private func terminal(_ command: String) async throws {
        // argv avoids interpolating commands into AppleScript source.
        let script = """
        on run argv
            tell application "Terminal"
                activate
                do script (item 1 of argv)
            end tell
        end run
        """
        _ = try await process("/usr/bin/osascript", ["-e", script, command])
    }

    private func process(_ executable: String, _ arguments: [String], directory: String? = nil) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                if let directory { process.currentDirectoryURL = URL(fileURLWithPath: directory) }
                // Drain concurrently through a file: verbose scripts cannot deadlock on a full pipe.
                let log = FileManager.default.temporaryDirectory.appendingPathComponent("pingagent-\(UUID().uuidString).log")
                FileManager.default.createFile(atPath: log.path, contents: nil)
                do {
                    let handle = try FileHandle(forWritingTo: log)
                    defer { try? handle.close(); try? FileManager.default.removeItem(at: log) }
                    process.standardOutput = handle; process.standardError = handle
                    process.standardInput = FileHandle.nullDevice
                    try process.run()
                    let deadline = Date().addingTimeInterval(60)
                    while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
                    if process.isRunning {
                        process.terminate()
                        continuation.resume(throwing: ActionFailure(message: "命令超过 60 秒，已请求终止。长时间任务请选择在 Terminal 中运行。"))
                        return
                    }
                    let reader = try FileHandle(forReadingFrom: log)
                    defer { try? reader.close() }
                    let output = String(decoding: try reader.read(upToCount: 8192) ?? Data(), as: UTF8.self)
                    guard process.terminationStatus == 0 else { throw ActionFailure(message: "执行失败（\(process.terminationStatus)）：\n\(output)") }
                    continuation.resume(returning: output)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
