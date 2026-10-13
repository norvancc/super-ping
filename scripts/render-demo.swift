// Documentation animation rendered with the app's production WheelCanvas.
// This is a scripted rendering demonstration, not a desktop recording.
import AppKit
import PingCore

@main
struct RenderDemo {
    static func main() throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let canvas = WheelCanvas(frame: NSRect(x: 0, y: 0, width: 560, height: 560))
        _ = PingAssets.images; _ = PingAssets.mutedImages
        for frame in 0..<140 {
            let t = Double(frame) / 20
            let sent = t >= 4.2
            func interpolate(_ a: NSPoint, _ b: NSPoint, _ progress: Double) -> NSPoint {
                let f = CGFloat(max(0, min(1, progress)))
                return NSPoint(x: a.x + (b.x-a.x)*f, y: a.y + (b.y-a.y)*f)
            }
            let pointer: NSPoint
            if t < 1.7 { pointer = interpolate(.zero, NSPoint(x: 0, y: 132), (t-1)/0.5) }
            else if t < 2.6 { pointer = interpolate(NSPoint(x: 0, y: 132), NSPoint(x: 0, y: -132), (t-1.7)/0.6) }
            else { pointer = interpolate(NSPoint(x: 0, y: -132), NSPoint(x: -132, y: 0), (t-2.6)/0.6) }
            let selection = CommandBuilder.selection(dx: Double(pointer.x)*600/560, dy: Double(pointer.y)*600/560)
            if canvas.selected != selection { canvas.selected = selection; Thread.sleep(forTimeInterval: 0.11) }
            canvas.pingOnly = sent ? .missing : nil
            canvas.fixedAge = sent ? min(t - 4.2, 2.7) : min(t, 0.2)
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1000, pixelsHigh: 640, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor(red: 0.045, green: 0.065, blue: 0.085, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 1000, height: 640).fill()
            func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: NSColor = .white) {
                (value as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: .medium), .foregroundColor: color])
            }
            let gold = NSColor(red: 0.98, green: 0.80, blue: 0.32, alpha: 1)
            text("SUPER PING", 48, 553, 30)
            text("A native macOS ping wheel", 48, 517, 16, .lightGray)
            text(sent ? "03  RELEASE" : (t < 1 ? "01  HOLD" : "02  DRAG"), 48, 390, 15, gold)
            text(sent ? "Send your ping." : (t < 1 ? "Option + mouse" : "Choose a direction."), 48, 341, 26)
            text(sent ? "Then run your chosen action." : (t < 1 ? "Hold the left mouse button." : "The selected ping lights up."), 48, 303, 16, .lightGray)
            text("Save a screenshot", 48, 210, 17)
            text("Open an app or run a shortcut", 48, 179, 17)
            text("Ask Codex about what you see", 48, 148, 17)
            text("8 directions. Your actions.", 48, 68, 15, gold)
            text("Native renderer demo • no desktop content", 48, 34, 12, .gray)
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform(); transform.translateX(by: 410, yBy: 45); transform.concat()
            canvas.draw(canvas.bounds)
            NSGraphicsContext.restoreGraphicsState()
            if !sent {
                let center = NSPoint(x: 690, y: 325)
                let offset = pointer
                let p = NSPoint(x: center.x + offset.x, y: center.y + offset.y)
                let cursor = NSBezierPath(); cursor.move(to: p); cursor.line(to: NSPoint(x:p.x+4,y:p.y-23)); cursor.line(to:NSPoint(x:p.x+10,y:p.y-15)); cursor.line(to:NSPoint(x:p.x+20,y:p.y-13)); cursor.close()
                NSColor.white.setFill(); cursor.fill(); NSColor.black.setStroke(); cursor.lineWidth=1.5;cursor.stroke()
            }
            NSGraphicsContext.restoreGraphicsState()
            try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(String(format: "%03d.png", frame)))
        }
    }
}
