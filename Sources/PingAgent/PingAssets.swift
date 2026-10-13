import AppKit
import CoreImage
import PingCore

enum PingAssets {
    static let bundle: Bundle = {
        if let resources = Bundle.main.resourceURL,
           let bundled = Bundle(url: resources.appendingPathComponent("PingAgent_PingAgent.bundle")) { return bundled }
        return Bundle.module
    }()
    static let names = ["pingwheel_retreatrender", "push", "omw", "all_in", "assist_me", "need_vision", "enemy_missing", "enemy_vision"]
    static let soundNames = ["SRP_12", "SRP_9", "OnMyWay", "SRP_4", "ComeHere", "SRP_7", "MIA", "AreaIsWarded"]
    static let images: [Ping: NSImage] = Dictionary(uniqueKeysWithValues: zip(Ping.allCases, names).compactMap { ping, name in
        guard let url = bundle.url(forResource: name, withExtension: "png", subdirectory: "Resources/textures"), let image = NSImage(contentsOf: url) else { return nil }
        return (ping, image)
    })
    private static let imageContext = CIContext(options: [.useSoftwareRenderer: false])
    static let mutedImages: [Ping: NSImage] = images.mapValues { image in
        guard let data = image.tiffRepresentation, let input = CIImage(data: data) else { return image }
        let filtered = input.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .applyingFilter("CISepiaTone", parameters: [kCIInputIntensityKey: 0.75])
        guard let bitmap = imageContext.createCGImage(filtered, from: filtered.extent) else { return image }
        return NSImage(cgImage: bitmap, size: image.size)
    }
    static func prewarm() {
        _ = images; _ = mutedImages
        PingAudio.shared.prepare(bundle: bundle, names: soundNames + ["button"])
    }
    static func hover() { PingAudio.shared.hover() }
    static func play(_ ping: Ping) {
        guard let index = Ping.allCases.firstIndex(of: ping) else { return }
        PingAudio.shared.play(soundNames[index])
    }
}
