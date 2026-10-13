import AppKit
import CoreImage
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let input = CIImage(contentsOf: url)!
let filtered = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0]).applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.75])
let live = NSImage(size: NSSize(width: 128, height: 128))
live.addRepresentation(NSCIImageRep(ciImage: filtered))
let raster = NSImage(cgImage: CIContext().createCGImage(filtered, from: filtered.extent)!, size: live.size)
let ctx = CGContext(data: nil, width: 1200, height: 1200, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
for (name, image) in [("live-filter",live),("cached-bitmap",raster)] {
    for _ in 0..<10 { image.draw(in: NSRect(x: 0,y:0,width:96,height:96)) }
    let start = CFAbsoluteTimeGetCurrent()
    for _ in 0..<200 {
        autoreleasepool { for i in 0..<8 { image.draw(in: NSRect(x: i*110,y:0,width:96,height:96)) } }
    }
    print("\(name): \((CFAbsoluteTimeGetCurrent()-start)*1000/200) ms per 8-icon frame")
}
