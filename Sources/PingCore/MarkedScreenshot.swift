import AppKit

/// Burns the marker into the PNG itself, independent of compositor/animation timing.
public enum MarkedScreenshot {
    public static func pixelPoint(global: CGPoint, screen: CGRect, width: Int, height: Int) -> CGPoint {
        CGPoint(x: (global.x - screen.minX) * CGFloat(width) / screen.width,
                y: (global.y - screen.minY) * CGFloat(height) / screen.height)
    }

    public static func render(_ background: CGImage, screen: CGRect, target: CGPoint, icon: CGImage) -> CGImage? {
        guard screen.width > 0, screen.height > 0,
              let context = CGContext(data: nil, width: background.width, height: background.height,
                  bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(background, in: CGRect(x: 0, y: 0, width: background.width, height: background.height))
        // AppKit coordinates and this bitmap context both point upwards. Convert once from display points.
        context.scaleBy(x: CGFloat(background.width) / screen.width, y: CGFloat(background.height) / screen.height)
        let point = CGPoint(x: target.x - screen.minX, y: target.y - screen.minY)
        let gold = CGColor(red: 1, green: 0.78, blue: 0.12, alpha: 1)
        let dark = CGColor(red: 0.08, green: 0.06, blue: 0.01, alpha: 1)
        let ring = CGRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)
        context.setStrokeColor(dark); context.setLineWidth(6); context.strokeEllipse(in: ring)
        context.setStrokeColor(gold); context.setLineWidth(3); context.strokeEllipse(in: ring)
        // Four short ticks identify the exact clicked position without covering its contents.
        for offset in [-1.0, 1.0] {
            let sign = CGFloat(offset)
            context.move(to: CGPoint(x: point.x + sign * 23, y: point.y))
            context.addLine(to: CGPoint(x: point.x + sign * 30, y: point.y))
            context.move(to: CGPoint(x: point.x, y: point.y + sign * 23))
            context.addLine(to: CGPoint(x: point.x, y: point.y + sign * 30))
        }
        context.strokePath()
        // Keep the icon entirely visible even for pings near a screen edge.
        let size: CGFloat = min(60, screen.width, screen.height)
        let x = max(0, min(screen.width - size, point.x - size / 2))
        let preferredY = point.y + 35
        let y = max(0, min(screen.height - size, preferredY + size > screen.height ? point.y - 35 - size : preferredY))
        let iconRect = CGRect(x: x, y: y, width: size, height: size)
        context.move(to: CGPoint(x: point.x, y: point.y + (y > point.y ? 20 : -20)))
        context.addLine(to: CGPoint(x: iconRect.midX, y: y > point.y ? iconRect.minY : iconRect.maxY))
        context.setLineWidth(2); context.strokePath()
        context.setShadow(offset: .zero, blur: 4, color: dark)
        context.draw(icon, in: iconRect)
        return context.makeImage()
    }
}
