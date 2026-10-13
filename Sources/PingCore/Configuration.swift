import Foundation

public enum Ping: String, CaseIterable, Codable, Identifiable {
    case danger, push, onMyWay, allIn, assist, needVision, missing, enemyVision
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .danger: return "危险"
        case .push: return "推进"
        case .onMyWay: return "正在路上"
        case .allIn: return "全力进攻"
        case .assist: return "请求协助"
        case .needVision: return "需要视野"
        case .missing: return "敌人消失 · 问号"
        case .enemyVision: return "敌方视野"
        }
    }
    public var symbol: String {
        switch self {
        case .danger: return "!"
        case .push: return "⇧"
        case .onMyWay: return "➜"
        case .allIn: return "⚔"
        case .assist: return "⚑"
        case .needVision: return "◎"
        case .missing: return "?"
        case .enemyVision: return "◉"
        }
    }
}

public enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case none, codexScreenshot, screenshot, screenshotClipboard, screenshotPreview, application, openURL, openFile, shortcut, copyText, script, command
    public var id: String { rawValue }
    public var requiresScreenshot: Bool {
        [.codexScreenshot, .screenshot, .screenshotClipboard, .screenshotPreview].contains(self)
    }
    public var requiresWorkingDirectory: Bool {
        [.codexScreenshot, .script, .command].contains(self)
    }
    public var title: String {
        switch self {
        case .none: return "仅显示 Ping"
        case .codexScreenshot: return "截图并询问 Codex"
        case .screenshot: return "仅截图并保存"
        case .screenshotClipboard: return "截图并复制到剪贴板"
        case .screenshotPreview: return "截图并打开预览"
        case .openURL: return "打开网页"
        case .openFile: return "打开文件或文件夹"
        case .shortcut: return "运行快捷指令"
        case .copyText: return "复制文字"
        case .application: return "打开应用"
        case .script: return "运行脚本文件"
        case .command: return "执行 Mac 命令"
        }
    }
}

public struct PingAction: Codable, Equatable {
    public var kind: ActionKind = .none
    public var value: String = ""
    public var runInTerminal = true
    public var prompt = "What's this mean?"
    public init(kind: ActionKind = .none) { self.kind = kind }
}

public struct Configuration: Codable {
    public var actions: [String: PingAction] = [Ping.missing.rawValue: PingAction(kind: .codexScreenshot)]
    public var sound = true
    public var codexExecutable = "codex"
    public var workingDirectory = "~"
    public init() {}
    public func action(for ping: Ping) -> PingAction { actions[ping.rawValue] ?? PingAction() }
}

public enum CommandBuilder {
    /// POSIX single-quote encoding. Values never become executable shell fragments.
    public static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }
    public static func codex(executable: String, image: String, prompt: String, directory: String) -> String {
        "cd " + quote(directory) + " && " + quote(executable) + " --image " + quote(image) + " -- " + quote(prompt)
    }
    /// dx/dy in AppKit coordinates (positive Y points upward).
    public static func selection(dx: Double, dy: Double, deadZone: Double = 86) -> Ping? {
        guard hypot(dx, dy) >= deadZone else { return nil }
        let angle = atan2(dx, dy)
        let index = Int((angle / (.pi / 4)).rounded())
        return Ping.allCases[(index + 8) % 8]
    }
}

public enum ActionInput {
    public static func webURL(_ value: String) -> URL? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
