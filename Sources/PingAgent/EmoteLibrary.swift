import AppKit
import ImageIO
import CryptoKit
import PingCore

final class EmoteLibrary {
    static let shared = EmoteLibrary()
    var directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("PingAgent/Emotes")
    var custom: [CustomEmote] = []
    private var icons: [String: NSImage] = [:]
    private struct Animation { let source: CGImageSource; let ends: [Double]; var index = -1; var image: NSImage? }
    private var animations: [String: Animation] = [:]
    private func url(_ id: String, animated: Bool) -> URL? {
        if EmoteDefinition.catalog.contains(where: {$0.id == id}) { return PingAssets.bundle.url(forResource:id,withExtension:animated ? "webp" : "png",subdirectory:"Resources/emotes") }
        return custom.first(where: {$0.id == id}).map { directory.appendingPathComponent($0.file) }
    }
    func name(_ id: String) -> String { EmoteDefinition.catalog.first { $0.id == id }?.title ?? custom.first { $0.id == id }?.name ?? "?" }
    func icon(_ id: String) -> NSImage? {
        if let icon = icons[id] { return icon }
        guard let url = url(id, animated: false), let source = CGImageSourceCreateWithURL(url as CFURL,nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:160] as CFDictionary) else { return nil }
        let image = NSImage(cgImage:cg,size:.zero); icons[id]=image;return image
    }
    func frame(_ id: String, age: Double) -> NSImage? {
        if animations[id] == nil {
            guard let url = url(id,animated:true), let source = CGImageSourceCreateWithURL(url as CFURL,nil) else {return icon(id)}
            var ends:[Double]=[],total=0.0
            for i in 0..<CGImageSourceGetCount(source) {
                let props=CGImageSourceCopyPropertiesAtIndex(source,i,nil) as? [String:Any] ?? [:]
                let animation=(props["{GIF}"] ?? props["{WebP}"]) as? [String:Any] ?? [:]
                total += max(0.01,(animation["UnclampedDelayTime"] ?? animation["DelayTime"]) as? Double ?? 0.1); ends.append(total)
            }
            if animations.count >= 4 { animations.removeAll() }
            animations[id]=Animation(source:source,ends:ends)
        }
        guard var a=animations[id],let duration=a.ends.last else {return icon(id)}
        let bundled=EmoteDefinition.catalog.contains {$0.id == id}
        let t=bundled ? min(age,duration) : age.truncatingRemainder(dividingBy:duration)
        let i=a.ends.firstIndex(where:{$0>t}) ?? a.ends.count-1
        if i != a.index, let image=CGImageSourceCreateImageAtIndex(a.source,i,nil) {a.image=NSImage(cgImage:image,size:.zero);a.index=i;animations[id]=a}
        return a.image ?? icon(id)
    }
    func importFile(_ url: URL) throws -> CustomEmote {
        let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size <= 8_388_608 else {throw ActionFailure(message:Localized.text("Image exceeds 8 MB.","图片超过 8 MB。"))}
        let data=try Data(contentsOf:url)
        guard let source=CGImageSourceCreateWithData(data as CFData,nil),let type=CGImageSourceGetType(source) as String?, ["public.png","public.jpeg","com.compuserve.gif","org.webmproject.webp"].contains(type),
              let props=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [String:Any],
              let w=props[kCGImagePropertyPixelWidth as String] as? Int,let h=props[kCGImagePropertyPixelHeight as String] as? Int,max(w,h)<=8192,
              CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:160] as CFDictionary) != nil else {throw ActionFailure(message:Localized.text("Choose a PNG, JPEG, GIF or WebP up to 8192 pixels.","请选择不超过 8192 像素的 PNG、JPEG、GIF 或 WebP。"))}
        let animated=CGImageSourceGetCount(source)>1
        guard !animated || (size<=5_242_880 && max(w,h)<=1024) else {throw ActionFailure(message:Localized.text("Animations must be at most 5 MB and 1024 pixels.","动图不得超过 5 MB、1024 像素。"))}
        let digest=SHA256.hash(data:data).map {String(format:"%02x",$0)}.joined()
        let filename=digest + ".image"
        guard !custom.contains(where:{$0.file==filename}) else {throw ActionFailure(message:Localized.text("This image has already been added.","该图片已经添加。"))}
        guard custom.count<24 else {throw ActionFailure(message:Localized.text("You can add up to 24 custom emotes.","最多添加 24 个自定义表情。"))}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try data.write(to:directory.appendingPathComponent(filename),options:.atomic)
        let name=String(url.deletingPathExtension().lastPathComponent.filter{!$0.isNewline && $0.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }}.prefix(24))
        return CustomEmote(id:UUID().uuidString,name:name,file:filename)
    }
    func remove(_ item: CustomEmote) {try? FileManager.default.removeItem(at:directory.appendingPathComponent(item.file));icons[item.id]=nil;animations[item.id]=nil}
    func play(_ id: String) {
        guard let url=PingAssets.bundle.url(forResource:id,withExtension:"wav",subdirectory:"Resources/emotes") else {return}
        PingAudio.shared.playFile(url)
    }
}
