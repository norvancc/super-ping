import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ServiceManagement
import PingCore

struct SettingsView: View {
    @ObservedObject var store: Store
    let previewEmote: (String) -> Void
    let captureKey: (Bool) -> Void
    let reconnect: () -> Void
    let tryWheel: () -> Void
    let testScreenshot: () -> Void
    let preview: (Ping) -> Void
    @State var section = 0
    @State private var picked: String?
    @State private var pickedTarget: Int?
    @State private var recording: String?
    @State private var keyMonitor: Any?
    private func t(_ en: String, _ zh: String) -> String { Localized.text(en, zh) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("SUPER PING").font(.title2.bold())
                Spacer()
                Toggle(t("Enabled", "启用"), isOn: $store.enabled)
            }
            Picker("", selection: $section) {
                Text(t("Controls", "操控")).tag(0)
                Text(t("Ping wheel", "Ping 轮盘")).tag(1)
                Text(t("Emotes", "表情")).tag(2)
                Text(t("Actions", "动作")).tag(3)
                Text(t("App", "应用")).tag(4)
            }.pickerStyle(.segmented)
            if section == 3 {
                ActionSettingsView(store: store, reconnect: reconnect, tryWheel: tryWheel, testScreenshot: testScreenshot, preview: preview)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch section {
                        case 0: controls
                        case 1: pingSettings
                        case 2: emoteSettings
                        default: appSettings
                        }
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text(store.status).font(.caption).foregroundStyle(.secondary).lineLimit(3).textSelection(.enabled)
        }.padding(20).frame(width: 950, height: 740)
        .onDisappear { stopRecording() }
        .onChange(of: section) { _ in picked = nil; pickedTarget = nil }
        .onExitCommand { picked = nil; pickedTarget = nil }
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(store.inputReady ? t("Global gestures connected", "全局手势已连接") : t("Accessibility permission needed", "需要辅助功能权限"), systemImage: store.inputReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Text(t("Hold a keyboard trigger and drag with the left mouse button, or drag with Mouse 4/5 itself. Release to send; return to the center or press Escape to cancel.", "按住键盘触发键并用左键拖动；鼠标侧键触发时，直接按住侧键拖动。松开发送，移回中心或按 Esc 取消。"))
            triggerPicker(emote: false)
            triggerPicker(emote: true)
            slider(t("Drag threshold", "拖动阈值"), value: $store.configuration.options.dragThreshold, range: 2...40, unit: "px")
            Toggle(t("Trigger + click sends a Ping", "触发键 + 单击发送 Ping"), isOn: $store.configuration.options.clickPing)
            Toggle(t("Trigger + click sends an emote", "表情触发键 + 单击发送表情"), isOn: $store.configuration.options.emoteClick)
            HStack {
                Text(t("Pause / resume shortcut", "暂停 / 恢复快捷键"))
                Text(shortcutLabel).monospaced()
                Button(recording == "pause" ? t("Press shortcut…", "请按快捷键…") : t("Record", "录制")) { record("pause") }
            }
            Toggle(t("Enable on launch", "启动时启用"), isOn: $store.configuration.options.enabledOnStart)
            HStack {
                Button(t("Try wheel", "试用轮盘"), action: tryWheel)
                Button(t("Reconnect", "重新连接"), action: reconnect)
                Button(t("Accessibility settings", "辅助功能设置")) { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }
            }
        }
    }
    private var pingSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            slider(t("Ping size", "Ping 大小"), value: $store.configuration.options.pingSize, range: 60...220, unit: "px")
            slider(t("Duration", "持续时间"), value: $store.configuration.options.pingDuration, range: 1...8, unit: "s")
            Toggle(t("Sound", "音效"), isOn: $store.configuration.sound)
            slider(t("Master volume", "总音量"), value: $store.configuration.options.volume, range: 0...100, unit: "%")
            Toggle(t("Wheel tick sound", "轮盘悬停音效"), isOn: $store.configuration.options.tickSound)
            Text(t("Choose an icon, then click a wheel slot. You can also drag icons to swap or replace them.", "先选内容，再点轮盘槽位；也可先选槽位再选内容，或直接拖动交换。"))
            wheelEditor(emotes: false)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                ForEach(Ping.allCases) { ping in tile(ping.rawValue, emote: false) }
            }
            Button(t("Reset wheel", "重置轮盘")) { store.configuration.options.wheel = Ping.defaultWheel; store.configuration.options.clickPingID = .generic }
        }
    }
    private var emoteSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            slider(t("Emote size", "表情大小"), value: $store.configuration.options.emoteSize, range: 80...300, unit: "px")
            Toggle(t("Emote sound", "表情音效"), isOn: $store.configuration.options.emoteSound)
            wheelEditor(emotes: true)
            Button(t("Reset emote wheel", "重置表情轮盘")) { store.configuration.options.emoteWheel = EmoteDefinition.defaultWheel; store.configuration.options.clickEmote = "facepalm" }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                ForEach(EmoteDefinition.catalog) { item in tile(item.id, emote: true) }
            }
            Divider()
            HStack {
                Text(t("Custom emotes", "自定义表情")).font(.headline)
                Text("\(store.configuration.options.customEmotes.count)/24").foregroundStyle(.secondary)
                Spacer()
                Button(t("Import images…", "导入图片…")) {
                    let panel = NSOpenPanel(); panel.allowsMultipleSelection = true
                    panel.allowedContentTypes = [.png, .jpeg, .gif, .webP]
                    if panel.runModal() == .OK { panel.urls.forEach(importImage) }
                }
            }
            Text(t("Drop PNG, JPEG, GIF or WebP here. Still images: 8 MB / 8192 px. Animations: 5 MB / 1024 px.", "拖入 PNG、JPEG、GIF 或 WebP。静态图片上限 8 MB / 8192 像素；动图上限 5 MB / 1024 像素。"))
            ForEach($store.configuration.options.customEmotes) { $item in
                HStack {
                    tile(item.id, emote: true).frame(width: 100)
                    TextField(t("Name", "名称"), text: Binding(get: {item.name}, set: {item.name = String($0.prefix(24))}))
                    Button(t("Remove", "删除")) {
                        EmoteLibrary.shared.remove(item)
                        store.configuration.options.customEmotes.removeAll { $0.id == item.id }
                        store.configuration.options.normalize()
                    }
                }
            }
        }.onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            for provider in providers { _ = provider.loadObject(ofClass: URL.self) { url, _ in if let url { DispatchQueue.main.async { importImage(url) } } } }
            return !providers.isEmpty
        }
    }
    private var appSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker(t("Language", "语言"), selection: $store.configuration.options.language) {
                Text("System / 系统").tag("auto"); Text("English").tag("en"); Text("简体中文").tag("zh-CN")
            }
            Toggle(t("Launch at login", "登录时启动"), isOn: Binding(get: { SMAppService.mainApp.status == .enabled }, set: { enabled in
                do {
                    if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    store.configuration.options.launchAtLogin = enabled
                } catch { store.status = error.localizedDescription }
            }))
            Toggle(t("Automatically check for updates", "自动检查更新"), isOn: $store.configuration.options.autoUpdateCheck)
            if let progress = store.updateProgress { ProgressView(value: progress).accessibilityLabel(t("Downloading update", "下载更新")) }
            Link(t("Release notes", "版本说明"), destination: URL(string: "https://github.com/norvancc/super-ping/releases/latest")!)
            Button(t("Check for updates", "检查更新")) { NotificationCenter.default.post(name: .init("SuperPingCheckUpdate"), object: nil) }
            Button(t("Open data folder", "打开数据目录")) { NSWorkspace.shared.open(store.directory) }
            Button(t("Check bundled assets", "检查内置素材")) {
                let problems = PingAssets.missingAssets()
                store.status = problems.isEmpty ? t("All Ping and emote images, animations and sounds are present.", "全部 Ping 和表情图像、动画及音效文件均完整。") : t("Missing: ", "缺少：") + problems.joined(separator: ", ")
            }
            Divider()
            Text("Super Ping \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")").font(.title2.bold())
            Text(t("A native macOS reimplementation of lolPing. Original artwork and audio belong to their respective owners.", "基于 lolPing 重构二次开发的 macOS 原生应用。原版美术和音效归其权利人所有。"))
            Link("Super Ping · GitHub", destination: URL(string: "https://github.com/norvancc/super-ping")!)
            Link("lolPing · Original project", destination: URL(string: "https://github.com/darrenprx/lolPing")!)
            Link("Licenses & third-party notices", destination: URL(string: "https://github.com/norvancc/super-ping/blob/main/THIRD_PARTY_NOTICES.txt")!)
        }
    }
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        HStack { Text(title).frame(width: 150, alignment: .leading); Slider(value: value, in: range, step: unit == "s" ? 0.1 : 1); Text(String(format: unit == "s" ? "%.1f %@" : "%.0f %@", value.wrappedValue, unit)).monospacedDigit().frame(width: 70) }
    }
    private func triggerPicker(emote: Bool) -> some View {
        let binding = Binding<Trigger>(get: { emote ? store.configuration.options.emoteTrigger : store.configuration.options.trigger }, set: {
            var candidate = store.configuration.options
            if emote { candidate.emoteTrigger = $0 } else { candidate.trigger = $0 }
            applyControls(candidate)
        })
        return HStack {
            Picker(t(emote ? "Emote trigger" : "Ping trigger", emote ? "表情触发键" : "Ping 触发键"), selection: binding) {
                ForEach(["option", "control", "shift", "command", "mouse4", "mouse5"] + (emote ? ["off"] : []), id: \.self) { kind in Text(Trigger(kind).title).tag(Trigger(kind)) }
                if binding.wrappedValue.kind == "custom" { Text(binding.wrappedValue.title).tag(binding.wrappedValue) }
            }
            Button(recording == (emote ? "emote" : "ping") ? t("Press key…", "请按键…") : t("Custom key…", "自定义按键…")) { record(emote ? "emote" : "ping") }
        }
    }
    private var shortcutLabel: String {
        let f = NSEvent.ModifierFlags(rawValue: UInt(store.configuration.options.hotkeyModifiers))
        return (f.contains(.control) ? "⌃" : "") + (f.contains(.option) ? "⌥" : "") + (f.contains(.shift) ? "⇧" : "") + (f.contains(.command) ? "⌘" : "") + KeyLabel.name(store.configuration.options.hotkeyCode)
    }
    private func record(_ target: String) {
        stopRecording(); recording = target; captureKey(true)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stopRecording() }
            guard event.keyCode != 53 else { return nil }
            var candidate = store.configuration.options
            if target == "pause" {
                let flags = event.modifierFlags.intersection([.control, .option, .command, .shift])
                guard !flags.intersection([.control, .option, .command]).isEmpty else { store.status = t("Include Control, Option or Command.", "请包含 Control、Option 或 Command。"); return nil }
                candidate.hotkeyCode = event.keyCode
                candidate.hotkeyModifiers = UInt64(flags.rawValue)
            } else if target == "emote" { candidate.emoteTrigger = Trigger("custom", keyCode: event.keyCode) }
            else { candidate.trigger = Trigger("custom", keyCode: event.keyCode) }
            applyControls(candidate)
            return nil
        }
    }
    private func applyControls(_ candidate: Options) {
        guard !candidate.triggersClash else { store.status = t("Ping, emote and pause keys conflict. Choose a different key.", "Ping、表情或暂停按键冲突，请换一个按键。"); return }
        store.configuration.options = candidate
        store.configuration.options.normalize()
    }
    private func stopRecording() { if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }; keyMonitor = nil; recording = nil; captureKey(false) }
    private func importImage(_ url: URL) {
        do { let item = try EmoteLibrary.shared.importFile(url); store.configuration.options.customEmotes.append(item) }
        catch { store.status = error.localizedDescription }
    }
    private func wheelEditor(emotes: Bool) -> some View {
        VStack(spacing: 8) {
            Text(picked == nil ? t("Choose an item, then click its destination. Dragging also works.", "选择内容后点击目标位置，也可以直接拖动。") : t("Selected — click a destination or press Escape to cancel.", "已选中 · 点击目标位置，或按 Esc 取消。"))
                .font(.callout).foregroundStyle(picked == nil ? Color.secondary : Color.accentColor)
            ZStack {
                Circle().fill(Color.secondary.opacity(0.1)).frame(width: 320, height: 320).allowsHitTesting(false)
                ForEach(0..<8) { index in
                    let angle = Double(index) * .pi / 4 - .pi / 2
                    let id = emotes ? store.configuration.options.emoteWheel[index] : store.configuration.options.wheel[index].rawValue
                    tile(id, emote: emotes, target: index).frame(width: 85, height: 70)
                        .offset(x: cos(angle)*125, y: sin(angle)*125)
                }
                VStack(spacing: 0) {
                    tile(emotes ? store.configuration.options.clickEmote : store.configuration.options.clickPingID.rawValue, emote: emotes, target: 8)
                    Text(t("Click center", "单击中心")).font(.caption2).allowsHitTesting(false)
                }.frame(width: 90, height: 90)
            }.frame(width: 350, height: 350).frame(maxWidth: .infinity)
        }
    }
    private func tile(_ id: String, emote: Bool, target: Int? = nil) -> some View {
        let image = emote ? EmoteLibrary.shared.icon(id) : Ping(rawValue: id).flatMap { PingAssets.images[$0] }
        let title = emote ? EmoteLibrary.shared.name(id) : Ping(rawValue: id)?.title ?? id
        let value = (emote ? "emote:" : "ping:") + id
        let location = target.map { $0 == 8 ? t("Center", "中心") : t("Slot", "槽位") + " \($0+1)" }
        return WheelTile(image: image, title: title, accessibilityTitle: (location.map { $0+": " } ?? t("Library: ", "内容库："))+title,
            payload: value, selected: picked == value && pickedTarget == target,
            onClick: {
                if let target {
                    if let picked { _ = place(picked, emotes: emote, target: target) }
                    else { picked = value; pickedTarget = target }
                } else if let destination = pickedTarget {
                    _ = place(value, emotes: emote, target: destination)
                } else {
                    picked = picked == value ? nil : value; pickedTarget = nil
                    if emote { previewEmote(id) } else if let ping = Ping(rawValue: id) { preview(ping) }
                }
            }, onDrop: target.map { destination in { value in place(value, emotes: emote, target: destination) } })
            .frame(height: 70)
    }
    @discardableResult private func place(_ value: String, emotes: Bool, target: Int) -> Bool {
        let prefix = emotes ? "emote:" : "ping:"
        guard value.hasPrefix(prefix), (0...8).contains(target) else { return false }
        let id = String(value.dropFirst(prefix.count))
        if emotes {
            guard (EmoteDefinition.catalog.map(\.id) + store.configuration.options.customEmotes.map(\.id)).contains(id) else { return false }
            if target < 8 { store.configuration.options.emoteWheel = Options.placing(id, in: store.configuration.options.emoteWheel, at: target) }
            else { store.configuration.options.clickEmote = id }
        } else {
            guard let ping = Ping(rawValue: id) else { return false }
            if target < 8 { store.configuration.options.wheel = Options.placing(ping, in: store.configuration.options.wheel, at: target) }
            else { store.configuration.options.clickPingID = ping }
        }
        picked = nil; pickedTarget = nil
        store.status = t("Wheel updated and saved.", "轮盘已更新并保存。")
        return true
    }
}
