import AppKit
import SwiftUI
import Combine
import PingCore

@main
enum PingAgentMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private let overlay = Overlay()
    private let input = InputMonitor()
    private let wheelPreview = WheelPreview()
    private var lastHover: Ping?
    private var contextTask: Task<PingContext, Never>?
    private var runner: ActionRunner!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var enabledSubscription: AnyCancellable?
    private var permissionTimer: Timer?
    private var optionsSubscription: AnyCancellable?
    private var emoteMode = false
    private var updater: Updater!
    private var trayMenu: NSMenu!
    private var pauseItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: id).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [.activateIgnoringOtherApps]); NSApp.terminate(nil); return
        }
        PingAssets.prewarm()
        runner = ActionRunner(store: store)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Super Ping")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        rebuildMenu()
        updater = Updater(store: store); updater.start()
        input.options = store.configuration.options
        overlay.options = store.configuration.options
        PingAudio.shared.setVolume(store.configuration.options.volume)
        optionsSubscription = store.$configuration.sink { [weak self] config in
            self?.input.options = config.options
            self?.overlay.options = config.options
            PingAudio.shared.setVolume(config.options.volume)
            Localized.preference = config.options.language
            self?.rebuildMenu()
        }
        input.onMode = { [weak self] mode in self?.emoteMode = mode; self?.overlay.emoteMode = mode }
        input.onPress = { [weak self] point in
            guard self?.emoteMode == false else { return }
            let height = NSScreen.screens.first?.frame.maxY ?? 0
            self?.contextTask = Task.detached(priority: .userInitiated) { ContextCapture.capture(point: point, primaryHeight: height) }
        }
        input.onStart = { [weak self] in self?.overlay.wheel(at: $0) }
        input.onMove = { [weak self] ping in
            guard let self else { return }
            self.overlay.update(ping)
            if ping != self.lastHover && ping != nil && self.store.configuration.sound && self.store.configuration.options.tickSound { PingAssets.hover() }
            self.lastHover = ping
        }
        input.onEvent = { [weak self] text in self?.store.inputStatus = text }
        input.onCancel = { [weak self] in self?.overlay.hide() }
        input.onToggle = { [weak self] in self?.toggle() }
        input.onEnd = { [weak self] ping, point in
            guard let self else { return }
            self.overlay.hide()
            guard let ping else { return }
            if self.emoteMode {
                let options = self.store.configuration.options
                let id = Ping.defaultWheel.firstIndex(of: ping).map { options.emoteWheel[$0] } ?? options.clickEmote
                self.overlay.emote(id, at: point)
                if self.store.configuration.sound && options.emoteSound { EmoteLibrary.shared.play(id) }
                return
            }
            if self.store.configuration.sound { PingAssets.play(ping) }
            if self.store.configuration.action(for: ping).kind.requiresScreenshot {
                self.capturePing(ping, at: point)

            } else {
                self.overlay.flash(ping, at: point)
                self.runner.run(ping, at: point)
            }
        }
        enabledSubscription = store.$enabled.sink { [weak self] enabled in
            self?.input.enabled = enabled
            self?.pauseItem.title = enabled ? Localized.text("Pause Ping", "暂停 Ping") : Localized.text("Resume Ping", "恢复 Ping")
        }
        connect()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !self.input.connected || !AXIsProcessTrusted() { self.connect() }
            }
        }
        let launchEvent = NSAppleEventManager.shared().currentAppleEvent
        let loginLaunch = launchEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !loginLaunch { showSettings() }
    }
    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: Localized.text("Settings…", "设置…"), action: #selector(showSettings), keyEquivalent: ",").target = self
        pauseItem = menu.addItem(withTitle: store.enabled ? Localized.text("Pause Ping", "暂停 Ping") : Localized.text("Resume Ping", "恢复 Ping"), action: #selector(toggle), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(withTitle: Localized.text("Reconnect input", "重新连接手势"), action: #selector(restartInput), keyEquivalent: "").target = self
        menu.addItem(withTitle: Localized.text("Check for updates…", "检查更新…"), action: #selector(checkUpdate), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: Localized.text("Quit Super Ping", "退出 Super Ping"), action: #selector(quit), keyEquivalent: "q").target = self
        trayMenu = menu
    }
    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp, let button = statusItem.button {
            trayMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
        } else { showSettings() }
    }
    @objc private func restartInput() { input.stop(); connect() }
    @objc private func checkUpdate() { Task { await updater.check(manual: true) } }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }


    private func capturePing(_ ping: Ping, at point: NSPoint, testOnly: Bool = false) {
        runner.run(ping, at: point, prepareScreenshot: { [weak self] in
            guard let self else { throw CancellationError() }
            self.input.enabled = false
            try await CaptureSequence.prepare(
                show: { self.overlay.flash(ping, at: point) },
                freeze: { self.overlay.freezeForCapture() },
                hide: { self.overlay.hideCapture() }
            )
        }, finishScreenshot: { [weak self] in
            guard let self else { return }
            self.overlay.hideCapture()
            self.input.enabled = self.store.enabled
        }, captureOnly: testOnly, contextTask: contextTask)
    }
    private func testScreenshot() {
        guard let screen = settingsWindow?.screen ?? NSScreen.main else { return }
        settingsWindow?.orderOut(nil)
        let point = NSPoint(x: screen.frame.midX, y: screen.frame.midY)
        let height = NSScreen.screens.first?.frame.maxY ?? 0
        contextTask = Task.detached(priority: .userInitiated) { ContextCapture.capture(point: point, primaryHeight: height) }
        capturePing(.missing, at: point, testOnly: true)
    }
    private func connect() {
        guard AXIsProcessTrusted() else {
            input.stop()
            store.inputReady = false
            store.inputStatus = "请在系统设置 → 隐私与安全性 → 辅助功能中允许当前 Super Ping。授权后会自动连接；若旧授权失效，请移除旧条目并重新添加当前应用。"
            return
        }
        store.inputReady = input.start()
        store.inputStatus = store.inputReady ? "按住 ⌥ Option + 鼠标左键，拖出中心圆后松开发送。" : "权限已授予，但监听连接失败。请退出并重新打开当前版本。"
    }
    private func showWheelPreview() {
        wheelPreview.show(options: store.configuration.options, onSend: { [weak self] ping, point in
            self?.overlay.flash(ping, at: point)
            if self?.store.configuration.sound == true { PingAssets.play(ping) }
        }, onHover: { [weak self] in
            if self?.store.configuration.sound == true { PingAssets.hover() }
        })
    }
    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 950, height: 740), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Super Ping"
            window.contentView = NSHostingView(rootView: SettingsView(store: store, previewEmote: { [weak self] id in
                self?.overlay.emote(id, at: NSEvent.mouseLocation)
                self?.store.status = Localized.text("Preview: ", "预览：") + EmoteLibrary.shared.name(id)
                if self?.store.configuration.sound == true && self?.store.configuration.options.emoteSound == true { EmoteLibrary.shared.play(id) }
            }, captureKey: { [weak self] in self?.input.capturingKey = $0 }, reconnect: { [weak self] in self?.input.stop(); self?.connect() }, tryWheel: { [weak self] in self?.showWheelPreview() }, testScreenshot: { [weak self] in self?.testScreenshot() }, preview: { [weak self] ping in
                guard let self else { return }
                self.overlay.flash(ping, at: NSEvent.mouseLocation)
                self.store.status = Localized.text("Preview: ", "预览：") + ping.title
                if self.store.configuration.sound { PingAssets.play(ping) }
            }))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    @objc private func toggle() { store.enabled.toggle() }
    @objc private func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { input.stop(); permissionTimer?.invalidate() }
}
