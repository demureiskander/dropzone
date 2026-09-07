import AppKit
import SwiftUI
import Quartz
import Combine
import DropzoneCore

@MainActor final class ShelfPanel: NSPanel {
    var owner: ShelfController?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = owner
        panel.delegate = owner
    }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) { panel.dataSource = nil; panel.delegate = nil }
}

@MainActor final class ShelfController: NSObject, NSMenuDelegate, @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let store = ShelfStore()
    let settings: Settings
    let panel: ShelfPanel
    var openSettings: (() -> Void)?
    private var motion = FollowMotion()
    private var inertia = InertialFollower()
    weak var menuAnchor: NSView?
    private var pointer = NSEvent.mouseLocation
    private var timer: Timer?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var subscriptions: Set<AnyCancellable> = []
    private var confirmingClose = false
    private var previewURLs: [URL] = []
    private var hosting: DropHostingView<ShelfView>!

    init(settings: Settings) {
        self.settings = settings
        panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 252, height: 254),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.owner = self
        panel.level = .floating; panel.isFloatingPanel = true; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.isReleasedWhenClosed = false; panel.acceptsMouseMovedEvents = true
        panel.title = "Dropzone — полка"
        hosting = DropHostingView(rootView: ShelfView(store: store, settings: settings, controller: self))
        hosting.onDrop = { [weak self] urls in self?.store.add(urls) }
        hosting.onHover = { [weak self] value in self?.store.hovering = value }
        hosting.onMenu = { [weak self] event in self?.showMenu(event: event) }
        hosting.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        panel.contentView = hosting
        settings.$follow.dropFirst().sink { [weak self] enabled in
            if enabled { self?.pointerMoved(NSEvent.mouseLocation) } else { self?.stopMotion() }
        }.store(in: &subscriptions)
    }
    var visible: Bool { panel.isVisible }
    func show(activate: Bool = false) {
        pointer = NSEvent.mouseLocation
        if !visible {
            let screen = screenAt(pointer)
            panel.setFrameOrigin(motion.target(pointer: pointer, size: panel.frame.size, screen: screen.visibleFrame))
        }
        panel.orderFrontRegardless()
        store.refresh()
        if activate { NSApp.activate(ignoringOtherApps: true); panel.makeKey(); panel.makeFirstResponder(hosting) }
        pointerMoved(pointer)
    }
    func hide() {
        panel.orderOut(nil); stopMotion()
        if QLPreviewPanel.sharedPreviewPanelExists() { QLPreviewPanel.shared()?.orderOut(nil) }
    }
    func closeShelf() {
        guard !confirmingClose else { return }
        if ClosePolicy.requiresConfirmation(count: store.closeItemCount, enabled: settings.confirmClose, threshold: settings.closeThreshold) {
            confirmingClose = true
            stopMotion()
            let alert = NSAlert()
            alert.messageText = "Закрыть полку и очистить содержимое?"
            alert.informativeText = "На полке элементов: \(store.closeItemCount). Оригиналы файлов останутся на месте."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Отмена")
            alert.addButton(withTitle: "Закрыть и очистить")
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            confirmingClose = false
            guard response == .alertSecondButtonReturn else { pointerMoved(NSEvent.mouseLocation); return }
        }
        store.clear()
        hide()
    }
    func toggle() { visible ? hide() : show(activate: true) }
    func setExpanded(_ value: Bool) {
        store.expanded = value
        let size = value ? CGSize(width: 500, height: 342) : CGSize(width: 252, height: 254)
        let origin = FollowMotion.clamp(CGPoint(x: panel.frame.minX, y: panel.frame.maxY - size.height), size: size, screen: screenAt(pointer).visibleFrame)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.makeKey(); panel.makeFirstResponder(hosting)
    }
    func screensChanged() {
        guard visible else { return }
        panel.setFrameOrigin(FollowMotion.clamp(panel.frame.origin, size: panel.frame.size, screen: screenAt(NSEvent.mouseLocation).visibleFrame))
    }
    func pointerMoved(_ point: CGPoint) {
        pointer = point
        let now = ProcessInfo.processInfo.systemUptime
        motion.observe(point, time: now)
        guard visible, settings.follow else { return }
        if timer == nil {
            lastTick = now
            let clock = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            clock.tolerance = 0.004
            RunLoop.main.add(clock, forMode: .common)
            timer = clock
        }
    }
    private func tick() {
        guard visible, settings.follow else { stopMotion(); return }
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTick; lastTick = now
        let interacting = confirmingClose || store.hovering || store.interaction || store.exporting || store.menuOpen || store.expanded || QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
        let paused = motion.isPaused(pointer: pointer, frame: panel.frame, time: now, interacting: interacting)
        if interacting { stopMotion(); return }
        let target = motion.target(pointer: pointer, size: panel.frame.size, screen: screenAt(pointer).visibleFrame)
        let clearance = InertialFollower.clearance(pointer: pointer, frame: panel.frame)
        let mobility = paused ? 0 : InertialFollower.mobility(clearance: clearance)
        let next = inertia.advance(from: panel.frame.origin, to: target, deltaTime: dt, mobility: mobility,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        // Never sweep a moving panel underneath the pointer.
        if NSRect(origin: next, size: panel.frame.size).insetBy(dx: -24, dy: -24).contains(pointer) { stopMotion(); return }
        let clamped = FollowMotion.clamp(next, size: panel.frame.size, screen: screenAt(pointer).visibleFrame)
        panel.setFrameOrigin(clamped)
        if paused && inertia.speed < 0.6 && panel.frame.insetBy(dx: -88, dy: -88).contains(pointer) { stopMotion() }
        if hypot(next.x - target.x, next.y - target.y) < 0.5 && inertia.speed < 1 { panel.setFrameOrigin(target); stopMotion() }
    }
    private func stopMotion() { timer?.invalidate(); timer = nil; inertia.reset() }
    private func screenAt(_ point: CGPoint) -> NSScreen { NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0] }
    func showMenu(event: NSEvent? = nil) {
        let menu = NSMenu(); menu.delegate = self
        let hasItems = !store.items.isEmpty
        func action(_ title: String, _ selector: Selector, _ enabled: Bool = true) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self; item.isEnabled = enabled; menu.addItem(item)
        }
        menu.autoenablesItems = false
        action("Открыть", #selector(openFiles), hasItems)
        action("Показать в Finder", #selector(reveal), hasItems)
        action("Быстрый просмотр", #selector(quickLook), hasItems)
        menu.addItem(.separator())
        action("Убрать с полки", #selector(removeSelected), hasItems)
        action("Очистить полку", #selector(clear), hasItems)
        menu.addItem(.separator())
        action("Следовать за курсором", #selector(toggleFollow))
        menu.items.last?.state = settings.follow ? .on : .off
        action("Настройки…", #selector(settingsAction))
        if let event { NSMenu.popUpContextMenu(menu, with: event, for: hosting) }
        else if let anchor = menuAnchor {
            let point = NSPoint(x: anchor.bounds.minX, y: anchor.isFlipped ? anchor.bounds.maxY + 5 : anchor.bounds.minY - 5)
            menu.popUp(positioning: nil, at: point, in: anchor)
        } else {
            let y = hosting.isFlipped ? 55.0 : hosting.bounds.height - 55
            menu.popUp(positioning: nil, at: NSPoint(x: hosting.bounds.width - 48, y: y), in: hosting)
        }
    }
    func menuWillOpen(_ menu: NSMenu) { store.menuOpen = true; stopMotion() }
    func menuDidClose(_ menu: NSMenu) { store.menuOpen = false; pointerMoved(NSEvent.mouseLocation) }
    @objc func reveal() { NSWorkspace.shared.activateFileViewerSelecting(store.validURLs()) }
    @objc private func openFiles() { for url in store.validURLs() { NSWorkspace.shared.open(url) } }
    @objc private func removeSelected() { store.removeSelection() }
    @objc private func clear() { store.clear() }
    @objc private func toggleFollow() { settings.follow.toggle() }
    @objc private func settingsAction() { openSettings?() }
    @objc func quickLook() {
        previewURLs = store.validURLs()
        guard !previewURLs.isEmpty, let preview = QLPreviewPanel.shared() else { return }
        panel.makeKey(); panel.makeFirstResponder(hosting)
        preview.dataSource = self; preview.delegate = self
        preview.reloadData(); preview.makeKeyAndOrderFront(nil)
    }
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { previewURLs.count }
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! { previewURLs[index] as NSURL }
    private func handleKey(_ event: NSEvent) -> Bool {
        guard panel.isKeyWindow else { return false }
        let command = event.modifierFlags.contains(.command)
        if command && event.charactersIgnoringModifiers == "a" { store.selectAll(); return true }
        if command && event.keyCode == 13 { closeShelf(); return true }
        if event.keyCode == 53 { hide(); return true }
        if event.keyCode == 49 && !command { quickLook(); return true }
        if event.keyCode == 51 { store.removeSelection(); return true }
        if event.keyCode == 36 { showMenu(); return true }
        if event.keyCode == 3 && command { settings.follow.toggle(); return true }
        if [123, 124, 125, 126].contains(event.keyCode), !store.items.isEmpty {
            let current = store.items.firstIndex { store.selection.contains($0.id) } ?? -1
            let direction = (event.keyCode == 123 || event.keyCode == 126) ? -1 : 1
            let index = min(max(current + direction, 0), store.items.count - 1)
            store.selection = [store.items[index].id]; return true
        }
        return false
    }
}
