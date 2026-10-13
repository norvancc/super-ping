import XCTest
import AppKit
@testable import PingCore

final class MarkedScreenshotTests: XCTestCase {
    private func solid(_ width: Int, _ height: Int, _ color: CGColor) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(color); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }
    private func rgb(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> [Int] {
        var pixel = [Int](repeating: 0, count: image.samplesPerPixel)
        image.getPixel(&pixel, atX: x, y: y)
        return pixel
    }
    func testRetinaAndNegativeDisplayOrigin() {
        let point = MarkedScreenshot.pixelPoint(global: CGPoint(x: -1200, y: 550), screen: CGRect(x: -1440, y: -200, width: 1440, height: 900), width: 2880, height: 1800)
        XCTAssertEqual(point.x, 480); XCTAssertEqual(point.y, 1500)
    }
    func testMarkerIsBurnedIntoPNGAtCorrectTarget() throws {
        for scale in [1, 2] {
            let background = solid(400 * scale, 300 * scale, CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [0.25, 0.25, 0.25, 1])!)
            let icon = solid(40, 40, CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [1, 0, 0, 1])!)
            let output = try XCTUnwrap(MarkedScreenshot.render(background, screen: CGRect(x: -400, y: 100, width: 400, height: 300), target: CGPoint(x: -250, y: 200), icon: icon))
            let data = try XCTUnwrap(NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:]))
            let decoded = try XCTUnwrap(NSBitmapImageRep(data: data))
            // Bitmap rows are top-down; target is local (150,100) in bottom-up coordinates.
            let ring = rgb(decoded, 168 * scale, 200 * scale)
            XCTAssertGreaterThan(ring[0], 200)
            XCTAssertGreaterThan(ring[1], 128)
            let badge = rgb(decoded, 150 * scale, 140 * scale)
            XCTAssertGreaterThan(badge[0], 230)
            XCTAssertLessThan(badge[1], 10)
            let untouched = rgb(decoded, 10, 10)
            let original = rgb(NSBitmapImageRep(cgImage: background), 10, 10)
            XCTAssertEqual(untouched, original)

        }
    }
    func testIconStaysVisibleAtScreenCorners() throws {
        let background = solid(400, 300, CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [0.25, 0.25, 0.25, 1])!)
        let icon = solid(40, 40, CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [1, 0, 0, 1])!)
        for point in [CGPoint(x: 1, y: 1), CGPoint(x: 399, y: 299)] {
            let output = try XCTUnwrap(MarkedScreenshot.render(background, screen: CGRect(x: 0, y: 0, width: 400, height: 300), target: point, icon: icon))
            let rep = NSBitmapImageRep(cgImage: output)
            let sample = point.x < 200 ? CGPoint(x: 30, y: 240) : CGPoint(x: 370, y: 65)
            let color = rgb(rep, Int(sample.x), Int(sample.y))
            XCTAssertGreaterThan(color[0], 230)
            XCTAssertLessThan(color[1], 10)
        }
    }
    func testBundledQuestionMarkPreview() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appendingPathComponent("Sources/PingAgent/Resources/textures/enemy_missing.png")
        let icon = try XCTUnwrap(NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let background = solid(800, 500, CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [0.18, 0.20, 0.24, 1])!)
        let output = try XCTUnwrap(MarkedScreenshot.render(background, screen: CGRect(x: 0, y: 0, width: 800, height: 500), target: CGPoint(x: 400, y: 220), icon: icon))
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: "/private/tmp/pingagent-marked-preview.png"))
    }

}
