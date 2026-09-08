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
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown { owner?.clearSelectionIfBackground(event) }
        super.sendEvent(event)
    }
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
    private var previousPointer: CGPoint?
    private var approachHoldUntil: TimeInterval = 0
    private var timer: Timer?
    private var frameAnimationTimer: Timer?
    private var visibilityTimer: Timer?
    private var wantsVisible = false
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
        panel.title = L("Dropzone — полка")
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
    var visible: Bool { wantsVisible }
    func show(activate: Bool = false) {
        pointer = NSEvent.mouseLocation
        if !panel.isVisible {
            panel.alphaValue = 0
            let screen = screenAt(pointer)
            panel.setFrameOrigin(motion.target(pointer: pointer, size: panel.frame.size, screen: screen.visibleFrame))
        }
        wantsVisible = true
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        animateVisibility(to: 1)
        store.refresh()
        if activate { NSApp.activate(ignoringOtherApps: true); panel.makeKey(); panel.makeFirstResponder(hosting) }
        pointerMoved(pointer)
    }
    func hide() {
        wantsVisible = false
        panel.ignoresMouseEvents = true
        stopMotion()
        animateVisibility(to: 0)
        if QLPreviewPanel.sharedPreviewPanelExists() { QLPreviewPanel.shared()?.orderOut(nil) }
    }
    private func animateVisibility(to target: CGFloat) {
        visibilityTimer?.invalidate()
        visibilityTimer = nil
        let start = panel.alphaValue
        guard panel.isVisible, abs(start - target) > 0.001 else {
            panel.alphaValue = target
            if target == 0 { panel.orderOut(nil) }
            return
        }
        let began = ProcessInfo.processInfo.systemUptime
        let duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.08 : (target == 1 ? 0.18 : 0.14)
        let clock = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] clock in
            MainActor.assumeIsolated {
                guard let self else { clock.invalidate(); return }
                let t = min((ProcessInfo.processInfo.systemUptime - began) / duration, 1)
                let eased = t * t * (3 - 2 * t)
                self.panel.alphaValue = start + (target - start) * eased
                if t >= 1 {
                    clock.invalidate()
                    self.visibilityTimer = nil
                    if !self.wantsVisible { self.panel.orderOut(nil) }
                }
            }
        }
        RunLoop.main.add(clock, forMode: .common)
        visibilityTimer = clock
    }
    func closeShelf() {
        guard !confirmingClose else { return }
        if ClosePolicy.requiresConfirmation(count: store.closeItemCount, enabled: settings.confirmClose, threshold: settings.closeThreshold) {
            confirmingClose = true
            stopMotion()
            let alert = NSAlert()
            alert.messageText = L("Закрыть полку и очистить содержимое?")
            alert.informativeText = (L("На полке элементов: ") + "\(store.closeItemCount)" + L(". Оригиналы файлов останутся на месте."))
            alert.alertStyle = .warning
            alert.addButton(withTitle: L("Отмена"))
            alert.addButton(withTitle: L("Закрыть и очистить"))
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
        guard store.expanded != value else { return }
        stopMotion()
        frameAnimationTimer?.invalidate()
        frameAnimationTimer = nil
        store.interaction = true
        store.expanded = value
        let size = value ? CGSize(width: 500, height: 342) : CGSize(width: 252, height: 254)
        let origin = FollowMotion.clamp(CGPoint(x: panel.frame.minX, y: panel.frame.maxY - size.height), size: size, screen: screenAt(pointer).visibleFrame)
        let target = NSRect(origin: origin, size: size)
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            panel.setFrame(target, display: true)
            finishExpansion()
            return
        }
        let start = panel.frame
        let began = ProcessInfo.processInfo.systemUptime
        let duration = 0.30
        let clock = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] clock in
            MainActor.assumeIsolated {
                guard let self else { clock.invalidate(); return }
                let progress = min((ProcessInfo.processInfo.systemUptime - began) / duration, 1)
                // Quintic smoothstep has zero velocity and acceleration at both ends.
                let eased = progress * progress * progress * (progress * (progress * 6 - 15) + 10)
                let frame = NSRect(
                    x: start.minX + (target.minX - start.minX) * eased,
                    y: start.minY + (target.minY - start.minY) * eased,
                    width: start.width + (target.width - start.width) * eased,
                    height: start.height + (target.height - start.height) * eased
                )
                self.panel.setFrame(frame, display: true)
                if progress >= 1 {
                    clock.invalidate()
                    self.frameAnimationTimer = nil
                    self.panel.setFrame(target, display: true)
                    self.finishExpansion()
                }
            }
        }
        clock.tolerance = 0.002
        RunLoop.main.add(clock, forMode: .common)
        frameAnimationTimer = clock
    }
    private func finishExpansion() {
        store.interaction = false
        approachHoldUntil = ProcessInfo.processInfo.systemUptime + 0.20
        panel.makeKey(); panel.makeFirstResponder(hosting)
    }
    fileprivate func clearSelectionIfBackground(_ event: NSEvent) {
        guard store.expanded, !store.selection.isEmpty,
              event.locationInWindow.y < panel.contentLayoutRect.height - 58 else { return }
        var view = panel.contentView?.hitTest(event.locationInWindow)
        while let current = view {
            if current is FileInteractionView { return }
            view = current.superview
        }
        store.clearSelection()
    }
    func screensChanged() {
        guard visible else { return }
        panel.setFrameOrigin(FollowMotion.clamp(panel.frame.origin, size: panel.frame.size, screen: screenAt(NSEvent.mouseLocation).visibleFrame))
    }
    func pointerMoved(_ point: CGPoint) {
        pointer = point
        let now = ProcessInfo.processInfo.systemUptime
        if let previousPointer, PointerApproach.isAimingAtShelf(previous: previousPointer, current: point, frame: panel.frame) {
            approachHoldUntil = now + 0.25
            stopMotion()
        }
        previousPointer = point
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
        let interacting = confirmingClose || now < approachHoldUntil || store.hovering || store.interaction || store.exporting || store.menuOpen || QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
        let paused = motion.isPaused(pointer: pointer, frame: panel.frame, time: now, interacting: interacting)
        if interacting { stopMotion(); return }
        let target = motion.target(pointer: pointer, size: panel.frame.size, screen: screenAt(pointer).visibleFrame)
        let clearance = InertialFollower.clearance(pointer: pointer, frame: panel.frame)
        let mobility = paused ? 0 : InertialFollower.mobility(clearance: clearance)
        let next = inertia.advance(from: panel.frame.origin, to: target, deltaTime: dt, mobility: mobility,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        // Never sweep a moving panel underneath the pointer.
        if NSRect(origin: next, size: panel.frame.size).insetBy(dx: -10, dy: -10).contains(pointer) { stopMotion(); return }
        let clamped = FollowMotion.clamp(next, size: panel.frame.size, screen: screenAt(pointer).visibleFrame)
        panel.setFrameOrigin(clamped)
        if paused && inertia.speed < 0.6 && panel.frame.insetBy(dx: -44, dy: -44).contains(pointer) { stopMotion() }
        if hypot(next.x - target.x, next.y - target.y) < 0.5 && inertia.speed < 1 { panel.setFrameOrigin(target); stopMotion() }
    }
    private func stopMotion() { timer?.invalidate(); timer = nil; inertia.reset() }
    func setInteraction(_ active: Bool) {
        store.interaction = active
        if active { approachHoldUntil = ProcessInfo.processInfo.systemUptime + 0.25; stopMotion() }
        else { pointerMoved(NSEvent.mouseLocation) }
    }
    private func screenAt(_ point: CGPoint) -> NSScreen { NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0] }
    func showMenu(event: NSEvent? = nil) {
        let menu = NSMenu(); menu.delegate = self
        let hasItems = !store.items.isEmpty
        func action(_ title: String, _ selector: Selector, _ enabled: Bool = true) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self; item.isEnabled = enabled; menu.addItem(item)
        }
        menu.autoenablesItems = false
        action(L("Открыть"), #selector(openFiles), hasItems)
        action(L("Показать в Finder"), #selector(reveal), hasItems)
        action(L("Быстрый просмотр"), #selector(quickLook), hasItems)
        menu.addItem(.separator())
        action(L("Убрать с полки"), #selector(removeSelected), hasItems)
        action(L("Очистить полку"), #selector(clear), hasItems)
        menu.addItem(.separator())
        action(L("Следовать за курсором"), #selector(toggleFollow))
        menu.items.last?.state = settings.follow ? .on : .off
        action(L("Настройки…"), #selector(settingsAction))
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
            store.select(store.items[index].id, additive: false); return true
        }
        return false
    }
}
