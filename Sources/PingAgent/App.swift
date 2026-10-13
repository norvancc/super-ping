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
    private var pauseItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        PingAssets.prewarm()
        runner = ActionRunner(store: store)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: "Super Ping")
        let menu = NSMenu()
        menu.addItem(withTitle: "Super Ping 设置…", action: #selector(showSettings), keyEquivalent: ",").target = self
        pauseItem = menu.addItem(withTitle: "暂停 Ping", action: #selector(toggle), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 Super Ping", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        input.onPress = { [weak self] point in
            let height = NSScreen.screens.first?.frame.maxY ?? 0
            self?.contextTask = Task.detached(priority: .userInitiated) { ContextCapture.capture(point: point, primaryHeight: height) }
        }
        input.onStart = { [weak self] in self?.overlay.wheel(at: $0) }
        input.onMove = { [weak self] ping in
            guard let self else { return }
            self.overlay.update(ping)
            if ping != self.lastHover && ping != nil && self.store.configuration.sound { PingAssets.hover() }
            self.lastHover = ping
        }
        input.onEvent = { [weak self] text in self?.store.inputStatus = text }
        input.onCancel = { [weak self] in self?.overlay.hide() }
        input.onToggle = { [weak self] in self?.toggle() }
        input.onEnd = { [weak self] ping, point in
            guard let self else { return }
            self.overlay.hide()
            guard let ping else { return }
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
            self?.pauseItem.title = enabled ? "暂停 Ping" : "恢复 Ping"
        }
        connect()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !self.input.connected || !AXIsProcessTrusted() { self.connect() }
            }
        }
        showSettings()
    }

    private func capturePing(_ ping: Ping, at point: NSPoint, testOnly: Bool = false) {
        runner.run(ping, at: point, prepareScreenshot: { [weak self] in
            guard let self else { throw CancellationError() }
            self.input.enabled = false
            try await CaptureSequence.prepare(
                show: { self.overlay.flash(ping, at: point) },
                freeze: { self.overlay.freezeForCapture() },
                hide: { self.overlay.hide() }
            )
        }, finishScreenshot: { [weak self] in
            guard let self else { return }
            self.overlay.hide()
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
        wheelPreview.show(onSend: { [weak self] ping, point in
            self?.overlay.flash(ping, at: point)
            if self?.store.configuration.sound == true { PingAssets.play(ping) }
        }, onHover: { [weak self] in
            if self?.store.configuration.sound == true { PingAssets.hover() }
        })
    }
    @objc private func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 680), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Super Ping"
            window.contentView = NSHostingView(rootView: SettingsView(store: store, reconnect: { [weak self] in self?.input.stop(); self?.connect() }, tryWheel: { [weak self] in self?.showWheelPreview() }, testScreenshot: { [weak self] in self?.testScreenshot() }, preview: { [weak self] ping in
                guard let self else { return }
                self.overlay.flash(ping, at: NSEvent.mouseLocation)
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
