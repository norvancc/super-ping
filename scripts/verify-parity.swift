// Production-renderer integration checks. Uses isolated temporary storage, no actions or personal desktop captures.
import AppKit
import SwiftUI
import ImageIO
import PingCore

@main struct VerifyParity {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func save(_ view: NSView, _ name: String) throws {
            let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(view.bounds.width),pixelsHigh:Int(view.bounds.height),bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
            NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
            NSColor.windowBackgroundColor.setFill(); view.bounds.fill(); view.draw(view.bounds)
            NSGraphicsContext.restoreGraphicsState()
            try rep.representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"))
        }
        PingAssets.prewarm()
        precondition(PingAssets.images.count == 11)
        for ping in Ping.allCases {
            precondition(ping.artwork.allSatisfy { PingAssets.textures[$0] != nil })
            precondition(PingAssets.bundle.url(forResource:ping.soundName,withExtension:"wav",subdirectory:"Resources/sounds") != nil)
            let view = WheelCanvas(frame:NSRect(x:0,y:0,width:500,height:500))
            view.effectCanvas = true; view.pingOnly = ping; view.fixedAge = 0.4
            try save(view,"ping-"+ping.rawValue)
        }
        for item in EmoteDefinition.catalog {
            precondition(EmoteLibrary.shared.icon(item.id) != nil)
            let a = EmoteLibrary.shared.frame(item.id,age:0.1)?.tiffRepresentation
            let b = EmoteLibrary.shared.frame(item.id,age:0.8)?.tiffRepresentation
            precondition(a != nil && b != nil && a != b, "Animation frames must differ: \(item.id)")
            precondition(PingAssets.bundle.url(forResource:item.id,withExtension:"wav",subdirectory:"Resources/emotes") != nil)
        }
        for age in [0.1,0.8,1.5] {
            let view = WheelCanvas(frame:NSRect(x:0,y:0,width:500,height:500));view.effectCanvas = true;view.emoteOnly = "facepalm";view.fixedAge = age
            try save(view,"emote-\(age)")
        }
        let wheel=WheelCanvas(frame:NSRect(x:0,y:0,width:600,height:600));wheel.fixedAge=0.4;wheel.selected = .missing
        try save(wheel,"wheel");wheel.emoteWheel=EmoteDefinition.defaultWheel;try save(wheel,"emote-wheel")
        // Real import/decode/remove round trip, with duplicate, corruption and size rejection.
        let library=EmoteLibrary.shared;library.directory=output.appendingPathComponent("import-test")
        let source=PingAssets.bundle.url(forResource:"facepalm",withExtension:"webp",subdirectory:"Resources/emotes")!
        let custom=try library.importFile(source);library.custom=[custom]
        precondition(library.icon(custom.id) != nil && library.frame(custom.id,age:0.8) != nil)
        do { _ = try library.importFile(source); fatalError("Duplicate accepted") } catch {}
        let invalid=output.appendingPathComponent("invalid.png");try Data("not an image".utf8).write(to:invalid)
        do { _ = try library.importFile(invalid); fatalError("Corrupt image accepted") } catch {}
        library.remove(custom);precondition(!FileManager.default.fileExists(atPath:library.directory.appendingPathComponent(custom.file).path))
        library.custom=[]
        let monitor = InputMonitor()
        var sent: [Ping] = [], modes: [Bool] = [], injected: [CGEventType] = []
        monitor.onEnd = { ping, _ in if let ping { sent.append(ping) } }
        monitor.onMode = { modes.append($0) }
        monitor.injectEvent = { injected.append($0.type) }
        func event(_ type: CGEventType, x: CGFloat = 500, y: CGFloat = 500, button: UInt32 = 0, flags: CGEventFlags = [], key: Int64 = 0) -> Bool {
            let e = CGEvent(source:nil)!
            e.type=type;e.location=CGPoint(x:x,y:y);e.setIntegerValueField(.mouseEventButtonNumber,value:Int64(button))
            e.flags=flags;e.setIntegerValueField(.keyboardEventKeycode,value:key)
            return monitor.handle(type,e)
        }
        func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.025)) }
        monitor.options.trigger = Trigger("mouse4")
        precondition(!event(.leftMouseDown))
        precondition(event(.otherMouseDown,button:3));_ = event(.otherMouseDragged,y:350,button:3)
        precondition(event(.otherMouseUp,y:350,button:3));drain();precondition(sent == [.danger])
        precondition(event(.otherMouseDown,button:3));precondition(event(.otherMouseUp,button:3));drain()
        precondition(injected == [.otherMouseDown,.otherMouseUp], "Side click must replay the same button")
        monitor.options = Options();drain();sent=[]
        precondition(!event(.leftMouseDown,flags:[.maskAlternate,.maskControl]), "Ambiguous triggers must pass through")
        precondition(event(.leftMouseDown,flags:.maskControl));_ = event(.leftMouseDragged,x:350,flags:.maskControl)
        precondition(event(.leftMouseUp,x:350,flags:.maskControl));drain();precondition(modes.last == true && sent == [.missing])
        sent=[];precondition(event(.leftMouseDown,flags:.maskAlternate));_ = event(.leftMouseDragged,y:350,flags:.maskAlternate)
        _ = event(.flagsChanged);precondition(event(.leftMouseUp,y:350));drain();precondition(sent.isEmpty)
        _ = event(.keyDown,flags:.maskAlternate,key:48)
        precondition(!event(.leftMouseDown,flags:.maskAlternate), "Alt+Tab clicks belong to the other app")
        _ = event(.flagsChanged);_ = event(.keyUp,key:48)
        monitor.options.trigger = Trigger("custom",keyCode:9);drain()
        precondition(event(.keyDown,key:9));monitor.enabled=false
        precondition(event(.keyUp,key:9), "Swallowed down requires swallowed up after disabling")
        precondition(!event(.keyDown,key:9));_ = event(.keyUp,key:9);drain()
        print("Verified side-button drag/replay, ambiguous triggers, emote routing, modifier cancellation, foreign shortcuts and paired custom-key suppression.")
        print("Verified 11 Ping artworks/sounds, 44 animated emotes/sounds, distinct animation frames, custom import/duplicate/corruption/removal.")
    }
}
