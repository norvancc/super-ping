import AppKit
import PingCore

final class WheelPreview {
    private var window: NSWindow?
    private var timer: Timer?
    func show(onSend: @escaping (Ping, NSPoint) -> Void, onHover: @escaping () -> Void) {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 680))
        let title = NSTextField(labelWithString: "轮盘试用 · 鼠标悬停高亮，拖动后松开发送")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.frame = NSRect(x: 25, y: 640, width: 575, height: 24); root.addSubview(title)
        let label = NSTextField(labelWithString: "此窗口不需要辅助功能权限，也不会执行自定义动作。")
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 25, y: 15, width: 575, height: 24); root.addSubview(label)
        let canvas = WheelCanvas(frame: NSRect(x: 10, y: 40, width: 600, height: 600))
        canvas.interactive = true
        var last: Ping?
        canvas.onHover = { ping in
            label.stringValue = ping.map { "当前选择：\($0.title) · 松开鼠标发送" } ?? "中心区域：取消 · 仅试用，不执行自定义动作"
            if ping != last && ping != nil { onHover() }; last = ping
        }
        canvas.onSelect = { [weak canvas] ping in
            guard let canvas, let window = canvas.window else { return }
            label.stringValue = "已发送：\(ping.title) · 动画与音效预览"
            onSend(ping, window.convertPoint(toScreen: canvas.convert(NSPoint(x: canvas.bounds.midX, y: canvas.bounds.midY), to: nil)))
        }
        root.addSubview(canvas)
        let window = NSWindow(contentRect: root.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Super Ping · 轮盘试用"; window.contentView = root; window.isReleasedWhenClosed = false
        window.acceptsMouseMovedEvents = true; window.appearance = NSAppearance(named: .darkAqua)
        window.center(); window.makeKeyAndOrderFront(nil); self.window = window
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak canvas, weak window] _ in
            if window?.isVisible == true && canvas?.isWheelAnimating == true { canvas?.needsDisplay = true }
        }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }
}
