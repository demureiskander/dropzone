import AppKit
import DropzoneCore

@MainActor final class ActivationController {
    let shelf: ShelfController
    let settings: Settings
    let notch: NotchController
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var detector = ShakeDetector()
    private var dragBaseline = NSPasteboard(name: .drag).changeCount
    private var pressed = false
    private var watchdog: Timer?
    init(shelf: ShelfController, settings: Settings) {
        self.shelf = shelf; self.settings = settings
        notch = NotchController(shelf: shelf)
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in self?.handle(event) }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in self?.handle(event); return event }
    }
    private func handle(_ event: NSEvent) {
        let point = NSEvent.mouseLocation
        shelf.pointerMoved(point)
        switch event.type {
        case .leftMouseDown:
            pressed = true; dragBaseline = NSPasteboard(name: .drag).changeCount; detector.reset()
        case .leftMouseUp:
            finishDrag()
        case .leftMouseDragged:
            guard pressed, !shelf.store.exporting else { return }
            let pasteboard = NSPasteboard(name: .drag)
            guard pasteboard.changeCount != dragBaseline, !FileDrag.urls(pasteboard).isEmpty else { return }
            if settings.shake, detector.update(point: point, time: ProcessInfo.processInfo.systemUptime, sensitivity: settings.sensitivity) {
                shelf.show()
            }
            if settings.notch { notch.update(pointer: point) } else { notch.hide() }
            startWatchdog()
        default: break
        }
    }
    private func startWatchdog() {
        guard watchdog == nil else { return }
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if NSEvent.pressedMouseButtons & 1 == 0 { self.finishDrag() }
            }
        }
        RunLoop.main.add(timer, forMode: .common); watchdog = timer
    }
    private func finishDrag() {
        pressed = false; detector.reset(); watchdog?.invalidate(); watchdog = nil
        // Let the destination receive performDragOperation before withdrawing the window.
        DispatchQueue.main.async { [weak self] in self?.notch.hide() }
    }
    func screensChanged() { notch.hide(); shelf.screensChanged() }
}

@MainActor final class NotchController {
    private let shelf: ShelfController
    private var panel: NSPanel?
    private var target: CGRect = .zero
    init(shelf: ShelfController) { self.shelf = shelf }
    func update(pointer: CGPoint) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
              screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea,
              right.minX > left.maxX else { hide(); return }
        let cutout = CGRect(x: left.maxX, y: screen.frame.maxY - screen.safeAreaInsets.top,
            width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
        let drop = cutout.insetBy(dx: -6, dy: -6)
        let proximity = cutout.insetBy(dx: -150, dy: -110)
        guard proximity.contains(pointer) else { hide(); return }
        if panel == nil || target != drop {
            hide(); target = drop
            let frame = drop.insetBy(dx: -28, dy: -28)
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            let view = NotchDropView(frame: NSRect(origin: .zero, size: frame.size))
            view.zone = NSRect(x: 28, y: 28, width: drop.width, height: drop.height)
            view.onDrop = { [weak self] urls in
                guard let self else { return }
                self.shelf.store.add(urls); self.shelf.show()
                DispatchQueue.main.async { self.hide() }
            }
            panel.contentView = view; self.panel = panel
        }
        (panel?.contentView as? NotchDropView)?.active = drop.contains(pointer)
        panel?.orderFrontRegardless()
    }
    func hide() { panel?.orderOut(nil); panel = nil }
}

@MainActor final class NotchDropView: NSView {
    var zone: CGRect = .zero
    var active = false { didSet { needsDisplay = true } }
    var onDrop: (([URL]) -> Void)?
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow(); shadow.shadowColor = NSColor.systemBlue.withAlphaComponent(active ? 0.95 : 0.65)
        shadow.shadowBlurRadius = active ? 14 : 22; shadow.set()
        let path = NSBezierPath(roundedRect: zone, xRadius: 9, yRadius: 9)
        NSColor.systemBlue.withAlphaComponent(active ? 0.23 : 0.14).setFill(); path.fill()
        NSColor.systemBlue.withAlphaComponent(active ? 1 : 0.3).setStroke()
        path.lineWidth = active ? 3 : 1; path.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
    private func operation(_ sender: NSDraggingInfo) -> NSDragOperation {
        active = zone.contains(convert(sender.draggingLocation, from: nil)) && FileDrag.accepts(sender)
        return active ? .copy : []
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { operation(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { operation(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { active = false }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { operation(sender) == .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard operation(sender) == .copy else { return false }
        onDrop?(FileDrag.urls(sender.draggingPasteboard)); return true
    }
}
