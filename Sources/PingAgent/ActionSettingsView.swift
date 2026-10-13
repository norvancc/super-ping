import SwiftUI
import AppKit
import PingCore

struct ActionSettingsView: View {
    @ObservedObject var store: Store
    @State private var selection = Ping.missing
    let reconnect: () -> Void
    let tryWheel: () -> Void
    let testScreenshot: () -> Void
    let preview: (Ping) -> Void
    private var action: Binding<PingAction> {
        Binding(get: { store.configuration.action(for: selection) }, set: { store.configuration.actions[selection.rawValue] = $0 })
    }
    private func t(_ en: String, _ zh: String) -> String { Localized.text(en, zh) }
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("SUPER PING").font(.system(size: 19, weight: .black, design: .rounded))
                Text(t("Give every signal a next step.", "让每个信号都有下一步。")).font(.caption).foregroundStyle(.secondary)
                ForEach(Ping.allCases) { ping in
                    Button { selection = ping } label: {
                        HStack(spacing: 12) {
                            pingIcon(ping, size: 28)
                            Text(ping.title).font(.system(size: 12, weight: .medium))
                            Spacer()
                            if store.configuration.action(for: ping).kind != .none { Circle().fill(Color.accentColor).frame(width: 5, height: 5) }
                        }.padding(6).background(selection == ping ? Color.white.opacity(0.09) : .clear).cornerRadius(8)
                    }.buttonStyle(.plain)
                }
                Spacer()
                Toggle(t("Enable global Ping", "启用全局 Ping"), isOn: $store.enabled)
                Text(t("Pause shortcut: see Controls", "⌃⌥P 暂停 / 恢复")).font(.caption).foregroundStyle(.secondary)
            }.padding(16).frame(width: 235).background(Color(nsColor: .windowBackgroundColor))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(store.inputReady ? t("Global gestures connected", "全局手势已连接") : t("Global gestures disconnected", "全局手势未连接"), systemImage: store.inputReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(store.inputReady ? .green : .orange).font(.headline)
                        Text(store.inputStatus).font(.caption).textSelection(.enabled)
                        HStack {
                            Button(t("Try wheel & hover", "试用轮盘与 Hover"), action: tryWheel)
                            if !store.inputReady { Button(t("Allow Accessibility", "开启辅助功能")) { privacy("Accessibility") } }
                            Button(t("Reconnect", "重新连接"), action: reconnect)
                        }
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.05)).cornerRadius(8)
                    HStack {
                        pingIcon(selection, size: 52)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(selection.title).font(.title2.bold())
                            Text(t("Action after releasing the mouse", "松开鼠标后执行的动作")).foregroundStyle(.secondary)
                            Button(t("Preview Ping (no action)", "预览 Ping（不执行动作）")) { preview(selection) }.font(.caption)
                        }
                        Spacer()
                    }
                    Button(t("Test screenshot (without Codex)", "实测截图（不发送 Codex）"), action: testScreenshot)
                    Picker(t("Action", "动作"), selection: action.kind) {
                        ForEach(ActionKind.allCases) { Text($0.title).tag($0) }
                    }
                    switch action.wrappedValue.kind {
                    case .none:
                        Text(t("Show Ping animation and play its sound.", "显示 Ping 动画并播放提示音。")).foregroundStyle(.secondary)
                    case .codexScreenshot:
                        Text(t("Show the real Ping, freeze the expanded animation, then capture it. Hide the Ping and open Terminal only after saving.", "显示实际 Ping 动画，待问号和波纹完整展开后暂停动画并截图；保存后才隐藏 Ping、打开 Terminal。")).foregroundStyle(.secondary)
                        Text(t("Prompt", "提示词")).font(.headline)
                        TextEditor(text: action.prompt).font(.system(.body, design: .monospaced)).frame(height: 70).border(Color.gray.opacity(0.25))
                        Text(t("Send the screenshot, application under the pointer and available browser title/URL to Codex. The browser may request Automation permission. Sign in to Codex first.", "截图、鼠标下方应用及可读取的浏览器标题/链接会一起发送给 Codex。浏览器可能请求自动化授权；读取失败仍发送截图。请先完成 codex 登录。")).font(.caption).foregroundStyle(.secondary)
                    case .screenshot, .screenshotClipboard, .screenshotPreview:
                        Text(t("Capture the display containing the Ping, including its visible marker, and save a PNG.", "截取 Ping 所在的整块屏幕，保留实际 Ping 标记，并保存为 PNG。不会启动 Terminal 或发送给 Codex。")).foregroundStyle(.secondary)
                        if action.wrappedValue.kind == .screenshotClipboard {
                            Text(t("Also copy the image to the clipboard.", "同时复制图片到剪贴板，可直接粘贴到聊天或文档。")).font(.caption).foregroundStyle(.secondary)
                        } else if action.wrappedValue.kind == .screenshotPreview {
                            Text(t("Open the saved image with the default image viewer.", "保存后使用默认图片应用打开。")).font(.caption).foregroundStyle(.secondary)
                        }
                    case .openURL:
                        TextField("https://example.com", text: action.value)
                        Text(t("Open the URL in your default browser.", "使用默认浏览器打开指定网页。")).font(.caption).foregroundStyle(.secondary)
                    case .openFile:
                        TextField(t("File or folder path", "文件或文件夹路径"), text: action.value)
                        Button(t("Choose file or folder…", "选择文件或文件夹…")) { chooseFile() }
                    case .shortcut:
                        TextField(t("Shortcut name", "快捷指令名称"), text: action.value)
                        Text(t("Enter the exact name from Shortcuts. Runs in the background with a 60-second timeout.", "填写“快捷指令”应用内的完整名称。后台运行，最长等待 60 秒。")).font(.caption).foregroundStyle(.secondary)
                        Button(t("Open Shortcuts", "打开快捷指令应用")) { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app")) }
                    case .copyText:
                        TextEditor(text: action.value).font(.system(.body, design: .monospaced)).frame(height: 100).border(Color.gray.opacity(0.25))
                        Text(t("Copy this text to the clipboard.", "将这段文字复制到剪贴板，方便随后粘贴。")).font(.caption).foregroundStyle(.secondary)
                    case .application:
                        TextField(t("Application path or bundle ID", "应用路径或 Bundle ID"), text: action.value)
                        Button(t("Choose app…", "选择应用…")) { chooseApplication() }
                    case .script:
                        TextField(t("Script path", "脚本文件路径"), text: action.value)
                        Button(t("Choose script…", "选择脚本…")) { chooseScript() }
                        Toggle(t("Run in Terminal", "在 Terminal 中运行"), isOn: action.runInTerminal)
                        Text(t("Supports shell scripts, AppleScript and executable scripts with a shebang.", "支持 .sh / .zsh / .bash、AppleScript，以及带 shebang 的可执行脚本。")).font(.caption).foregroundStyle(.secondary)
                    case .command:
                        TextEditor(text: action.value).font(.system(.body, design: .monospaced)).frame(height: 100).border(Color.gray.opacity(0.25))
                        Toggle(t("Run in Terminal", "在 Terminal 中运行"), isOn: action.runInTerminal)
                        Text("例如：open -a Safari，或 shortcuts run '我的快捷指令'\n可使用 PING_KIND、PING_X、PING_Y 环境变量。后台命令通过 zsh 执行，限时 60 秒。").font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    Text(t("General settings", "通用设置")).font(.headline)
                    Toggle(t("Play sound", "播放提示音"), isOn: $store.configuration.sound)
                    LabeledContent(t("Codex executable", "Codex 路径")) { TextField("codex", text: $store.configuration.codexExecutable) }
                    LabeledContent(t("Working directory", "工作目录")) {
                        TextField("~", text: $store.configuration.workingDirectory)
                        Button(t("Choose…", "选择…")) { chooseDirectory() }
                    }
                    Text(t("If Terminal cannot find codex, enter its full executable path.", "如果 Terminal 找不到 codex，请填写可执行文件的完整路径，例如 ~/.local/bin/codex。")).font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text(t("Permissions", "权限与使用")).font(.headline)
                    Text(t("Hold your configured trigger and drag with the left mouse button. Return to the center, press Escape or release the trigger to cancel.", "按住 ⌥ Option + 鼠标左键拖动，松开鼠标发送。移回中心、按 Esc 或松开 Option 取消。问号位于轮盘左侧。")).font(.callout)
                    HStack {
                        Button(t("Accessibility", "辅助功能权限")) { privacy("Accessibility") }
                        Button(t("Screen Recording", "屏幕录制权限")) { privacy("ScreenCapture") }
                        Button(t("Reconnect gestures", "重新连接手势"), action: reconnect)
                    }
                    Button(t("Open screenshots folder", "打开截图文件夹")) {
                        let folder = store.directory.appendingPathComponent("Screenshots")
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(folder)
                    }
                    Text(store.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Text(t("Settings save automatically · Native macOS · Reimplemented from lolPing", "设置自动保存 · macOS 原生 · 基于 lolPing 重构二次开发")).font(.caption2).foregroundStyle(.tertiary)
                }.padding(28)
            }.frame(minWidth: 480)
        }.frame(minWidth: 800, minHeight: 620)
    }
    @ViewBuilder private func pingIcon(_ ping: Ping, size: CGFloat) -> some View {
        if let image = PingAssets.images[ping] {
            Image(nsImage: image).resizable().scaledToFit().frame(width: size, height: size)
        } else { Text(ping.symbol).font(.system(size: size, weight: .bold)).foregroundColor(Color(nsColor: ping.color)) }
    }
    private func privacy(_ name: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(name)") { NSWorkspace.shared.open(url) }
    }
    private func chooseApplication() {
        let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        if panel.runModal() == .OK, let url = panel.url { action.wrappedValue.value = url.path }
    }
    private func chooseFile() {
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true
        if panel.runModal() == .OK, let url = panel.url { action.wrappedValue.value = url.path }
    }
    private func chooseScript() {
        let panel = NSOpenPanel()
        if panel.runModal() == .OK, let url = panel.url { action.wrappedValue.value = url.path }
    }
    private func chooseDirectory() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url { store.configuration.workingDirectory = url.path }
    }
}
