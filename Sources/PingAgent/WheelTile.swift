import AppKit
import SwiftUI

/// AppKit owns drag sessions and drop hit testing; SwiftUI only supplies tile state.
struct WheelTile: NSViewRepresentable {
    var image: NSImage?
    var title: String
    var accessibilityTitle: String
    var payload: String
    var selected: Bool
    var onClick: () -> Void
    var onDrop: ((String) -> Bool)?
    func makeNSView(context: Context) -> TileButton { TileButton(frame: .zero) }
    func updateNSView(_ view: TileButton, context: Context) {
        view.art = image; view.caption = title; view.payload = payload; view.picked = selected
        view.clicked = onClick; view.dropped = onDrop
        view.setAccessibilityLabel(accessibilityTitle); view.toolTip = accessibilityTitle
        view.needsDisplay = true
    }
}
final class TileButton: NSButton, NSDraggingSource {
    var art: NSImage?
    var caption = ""
    var payload = ""
    var picked = false
    var clicked: (() -> Void)?
    var dropped: ((String) -> Bool)?
    private var dropHover = false
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false; title = ""; target = self; action = #selector(activateTile)
        registerForDraggedTypes([.string])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func activateTile() { clicked?() }
    override func accessibilityPerformPress() -> Bool { clicked?(); return true }
    override var isFlipped: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 2, dy: 2)
        if picked || dropHover {
            NSColor.controlAccentColor.withAlphaComponent(dropHover ? 0.26 : 0.15).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            NSColor.controlAccentColor.setStroke()
            let outline = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8); outline.lineWidth = 2; outline.stroke()
        }
        if let art {
            let scale = min(40/max(1,art.size.width),40/max(1,art.size.height))
            let size = NSSize(width: art.size.width*scale, height: art.size.height*scale)
            art.draw(in: NSRect(x: bounds.midX-size.width/2, y: bounds.maxY-7-size.height, width:size.width,height:size.height))
        }
        let style = NSMutableParagraphStyle();style.alignment = .center;style.lineBreakMode = .byTruncatingTail
        (caption as NSString).draw(in: NSRect(x:4,y:5,width:bounds.width-8,height:17),withAttributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.labelColor,.paragraphStyle:style])
    }
    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let start = event.locationInWindow
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { clicked?(); return }
            let point = next.locationInWindow
            guard hypot(point.x-start.x,point.y-start.y) >= 4 else { continue }
            let item = NSDraggingItem(pasteboardWriter: payload as NSString)
            item.setDraggingFrame(NSRect(x:bounds.midX-22,y:bounds.midY-22,width:44,height:44),contents:art)
            beginDraggingSession(with:[item],event:next,source:self)
            return
        }
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .move }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { updateDrop(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { updateDrop(sender) }
    private func updateDrop(_ sender: NSDraggingInfo) -> NSDragOperation {
        let incoming = sender.draggingPasteboard.string(forType: .string) ?? ""
        dropHover = dropped != nil && incoming.split(separator:":").first == payload.split(separator:":").first
        needsDisplay = true
        return dropHover ? .move : []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { dropHover = false; needsDisplay = true }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { dropHover }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { dropHover = false; needsDisplay = true }
        guard let value = sender.draggingPasteboard.string(forType:.string) else { return false }
        return dropped?(value) ?? false
    }
}
