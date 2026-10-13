import AppKit
import CoreImage
import PingCore

enum PingAssets {
    static let bundle: Bundle = {
        if let resources = Bundle.main.resourceURL,
           let bundled = Bundle(url: resources.appendingPathComponent("PingAgent_PingAgent.bundle")) { return bundled }
        return Bundle.module
    }()
    static let names = Ping.allCases.map(\.icon)
    static let soundNames = Ping.allCases.map(\.soundName)
    static let textures: [String: NSImage] = Dictionary(uniqueKeysWithValues: Set(Ping.allCases.flatMap { [$0.icon] + $0.artwork }).compactMap { name in
        guard let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Resources/textures"), let image = NSImage(contentsOf: url) else { return nil }
        return (name, image)
    })
    static let images: [Ping: NSImage] = Dictionary(uniqueKeysWithValues: Ping.allCases.compactMap { ping in textures[ping.icon].map { (ping, $0) } })
    private static let imageContext = CIContext(options: [.useSoftwareRenderer: false])
    static let mutedImages: [Ping: NSImage] = images.mapValues { image in
        guard let data = image.tiffRepresentation, let input = CIImage(data: data) else { return image }
        let filtered = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.75])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 1.3])
            .applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x:1.15,y:0,z:0,w:0), "inputGVector": CIVector(x:0,y:1.15,z:0,w:0), "inputBVector": CIVector(x:0,y:0,z:1.15,w:0)])
        guard let bitmap = imageContext.createCGImage(filtered, from: filtered.extent) else { return image }
        return NSImage(cgImage: bitmap, size: image.size)
    }
    static func missingAssets() -> [String] {
        var files = Set(Ping.allCases.flatMap { [$0.icon] + $0.artwork }).map { ("textures", $0, "png") }
        files += (soundNames + ["button"]).map { ("sounds", $0, "wav") }
        files += EmoteDefinition.catalog.flatMap { item in ["png", "webp", "wav"].map { ("emotes", item.id, $0) } }
        return files.compactMap { folder, name, ext in bundle.url(forResource: name, withExtension: ext, subdirectory: "Resources/"+folder) == nil ? "\(folder)/\(name).\(ext)" : nil }
    }
    static func prewarm() {
        _ = images; _ = mutedImages
        PingAudio.shared.prepare(bundle: bundle, names: soundNames + ["button"])
        PingAudio.shared.prepareFiles(EmoteDefinition.catalog.compactMap { bundle.url(forResource: $0.id, withExtension: "wav", subdirectory: "Resources/emotes") })
    }
    static func hover() { PingAudio.shared.hover() }
    static func play(_ ping: Ping) {
        PingAudio.shared.play(ping.soundName)
    }
}
