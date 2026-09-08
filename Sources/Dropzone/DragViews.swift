import AppKit
import SwiftUI

@MainActor enum FileDrag {
    static func urls(_ pasteboard: NSPasteboard) -> [URL] {
        (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
    }
    static func accepts(_ info: NSDraggingInfo) -> Bool {
        info.draggingSourceOperationMask.contains(.copy) && !urls(info.draggingPasteboard).isEmpty
    }
}

@MainActor final class DropHostingView<Content: View>: NSHostingView<Content> {
    var onDrop: (([URL]) -> Void)?
    var onHover: ((Bool) -> Void)?
    var onMenu: ((NSEvent) -> Void)?
    var onKey: ((NSEvent) -> Bool)?
    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let accepted = FileDrag.accepts(sender)
        onHover?(accepted)
        if accepted { enlarge(sender) }
        return accepted ? .copy : []
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDrag.accepts(sender) ? .copy : []
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { onHover?(false) }
    override func draggingEnded(_ sender: NSDraggingInfo) { onHover?(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { FileDrag.accepts(sender) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { onHover?(false) }
        guard FileDrag.accepts(sender) else { return false }
        onDrop?(FileDrag.urls(sender.draggingPasteboard))
        return true
    }
    private func enlarge(_ info: NSDraggingInfo) {
        // AppKit resets destination overrides when leaving this destination.
        info.enumerateDraggingItems(options: [], for: self, classes: [NSPasteboardItem.self], searchOptions: [:]) { item, _, _ in
            let frame = item.draggingFrame
            guard frame.width > 0, frame.height > 0 else { return }
            let scale = min(1.65, 112 / max(frame.width, frame.height))
            guard scale > 1 else { return }
            item.draggingFrame = NSRect(x: frame.midX - frame.width * scale / 2,
                y: frame.midY - frame.height * scale / 2, width: frame.width * scale, height: frame.height * scale)
        }
    }
    override func rightMouseDown(with event: NSEvent) { onMenu?(event) }
    override func keyDown(with event: NSEvent) {
        if onKey?(event) != true { super.keyDown(with: event) }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKey?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

struct FileInteraction: NSViewRepresentable {
    let id: String?
    let store: ShelfStore
    var onDoubleClick: () -> Void
    var onContext: (NSEvent) -> Void
    var onDragEnd: (NSDragOperation) -> Void
    var onInteraction: (Bool) -> Void
    func makeNSView(context: Context) -> FileInteractionView { FileInteractionView() }
    func updateNSView(_ view: FileInteractionView, context: Context) {
        view.itemID = id; view.store = store
        view.onDoubleClick = onDoubleClick; view.onContext = onContext; view.onDragEnd = onDragEnd
        view.onInteraction = onInteraction
    }
}

@MainActor final class FileInteractionView: NSView, NSDraggingSource {
    var itemID: String?
    weak var store: ShelfStore?
    var onDoubleClick: (() -> Void)?
    var onContext: ((NSEvent) -> Void)?
    var onDragEnd: ((NSDragOperation) -> Void)?
    var onInteraction: ((Bool) -> Void)?
    private var start: NSEvent?
    private var exportedIDs: Set<String> = []
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        onInteraction?(true)
        window?.makeKey(); window?.makeFirstResponder(superview)
        if event.modifierFlags.contains(.control) { onInteraction?(false); rightMouseDown(with: event); return }
        start = event
        if let id = itemID {
            if event.modifierFlags.contains(.command) { store?.select(id, additive: true) }
            else if event.modifierFlags.contains(.shift) { store?.select(id, additive: false, range: true) }
            else if store?.selection.contains(id) != true { store?.select(id, additive: false) }
        }
        if event.clickCount == 2 { onDoubleClick?() }
    }
    override func mouseUp(with event: NSEvent) { start = nil; onInteraction?(false) }
    override func rightMouseDown(with event: NSEvent) {
        if let id = itemID, store?.selection.contains(id) != true { store?.select(id, additive: false) }
        onContext?(event)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start, let store else { return }
        guard hypot(event.locationInWindow.x - start.locationInWindow.x, event.locationInWindow.y - start.locationInWindow.y) > 4 else { return }
        if itemID == nil { store.selection = [] }
        let payload = store.exportPayload()
        let urls = payload.urls
        guard !urls.isEmpty else { onInteraction?(false); return }
        exportedIDs = payload.ids
        self.start = nil
        let p = convert(event.locationInWindow, from: nil)
        let drags = urls.map { url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            item.setDraggingFrame(NSRect(x: p.x - 24, y: p.y - 24, width: 48, height: 48), contents: icon)
            return item
        }
        store.exporting = true
        let session = beginDraggingSession(with: drags, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = .pile
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        store?.exporting = false
        if operation != [] { store?.remove(ids: exportedIDs) }
        exportedIDs = []
        onInteraction?(false)
        onDragEnd?(operation)
    }
}

struct WindowHandle: NSViewRepresentable {
    var onMoving: (Bool) -> Void
    func makeNSView(context: Context) -> HandleView { HandleView() }
    func updateNSView(_ nsView: HandleView, context: Context) { nsView.onMoving = onMoving }
}
@MainActor final class HandleView: NSView {
    var onMoving: ((Bool) -> Void)?
    override func mouseDown(with event: NSEvent) {
        onMoving?(true); window?.performDrag(with: event); onMoving?(false)
    }
}
