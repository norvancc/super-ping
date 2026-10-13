import AppKit
import Combine
import PingCore

final class Store: ObservableObject {
    @Published var configuration: Configuration { didSet { save() } }
    @Published var status = "按住 ⌥ Option，按下鼠标并拖向一个 Ping，松开鼠标执行。"
    @Published var inputStatus = "正在连接全局手势…"
    @Published var inputReady = false
    @Published var enabled = true
    let directory: URL
    private let file: URL
    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PingAgent", isDirectory: true)
        file = directory.appendingPathComponent("settings.json")
        var warning: String?
        if FileManager.default.fileExists(atPath: file.path) {
            do { configuration = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: file)) }
            catch {
                configuration = Configuration()
                let backup = directory.appendingPathComponent("settings-unreadable-\(UUID().uuidString).json")
                try? FileManager.default.copyItem(at: file, to: backup)
                warning = "设置读取失败，已保留原文件并恢复默认值：\(error.localizedDescription)"
            }
        } else { configuration = Configuration() }
        if let warning { status = warning }
    }
    private func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(configuration).write(to: file, options: .atomic)
        } catch { status = "无法保存设置：\(error.localizedDescription)" }
    }
}
