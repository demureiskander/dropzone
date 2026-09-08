import AppKit
import SwiftUI
import Combine
import Carbon

@main enum DropzoneApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(Settings.shared.showDock ? .regular : .accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private var shelf: ShelfController!
    private var activation: ActivationController!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var hotKey: HotKey!
    private var settingsKeyMonitor: Any?
    private var subscriptions: Set<AnyCancellable> = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        settings.applyTheme()
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        let preferences = NSMenuItem(title: L("Настройки…"), action: #selector(showSettings), keyEquivalent: ",")
        preferences.target = self; appMenu.addItem(preferences)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: L("Завершить Dropzone"), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self; appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu; mainMenu.addItem(appMenuItem); NSApp.mainMenu = mainMenu
        // Use the physical comma key, so Russian Б and other layouts work too.
        // Local scope preserves the standard Settings shortcut in other applications.
        settingsKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == UInt16(kVK_ANSI_Comma), modifiers == .command {
                self?.showSettings()
                return nil
            }
            return event
        }
        shelf = ShelfController(settings: settings)
        shelf.openSettings = { [weak self] in self?.showSettings() }
        settings.$language.dropFirst().receive(on: RunLoop.main).sink { [weak self] _ in
            guard let self else { return }
            preferences.title = L("Настройки…")
            quitItem.title = L("Завершить Dropzone")
            self.settingsWindow?.title = L("Dropzone — настройки")
            self.shelf.panel.title = L("Dropzone — полка")
            self.statusItem.button?.toolTip = L("Dropzone — нажмите или перетащите файлы")
        }.store(in: &subscriptions)
        activation = ActivationController(shelf: shelf, settings: settings)
        hotKey = HotKey(); hotKey.action = { [weak self] in self?.shelf.toggle() }
        hotKey.register(settings: settings)
        Publishers.CombineLatest3(settings.$shortcutKey, settings.$shortcutModifiers, settings.$shortcutEnabled)
            .dropFirst().debounce(for: .milliseconds(120), scheduler: RunLoop.main)
            .sink { [weak self] _ in guard let self else { return }; self.hotKey.register(settings: self.settings) }.store(in: &subscriptions)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "tray.and.arrow.down.fill", accessibilityDescription: "Dropzone")
            image?.isTemplate = true
            image?.size = NSSize(width: 17, height: 17)
            button.image = image
            let view = StatusDropView(frame: button.bounds)
            view.autoresizingMask = [.width, .height]
            view.onClick = { [weak self] event in
                if event.type == .rightMouseUp { self?.showStatusMenu() } else { self?.shelf.toggle() }
            }
            view.onDrop = { [weak self] urls in self?.shelf.store.add(urls); self?.shelf.show() }
            button.addSubview(view)
            button.toolTip = L("Dropzone — нажмите или перетащите файлы")
        }
        settings.$showMenuBar.sink { [weak self] visible in
            self?.statusItem.isVisible = visible
        }.store(in: &subscriptions)
        settings.$showDock.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] visible in
            self?.applyDockVisibility(visible)
        }.store(in: &subscriptions)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(screensChanged), name: NSWorkspace.didWakeNotification, object: nil)
        if !UserDefaults.standard.bool(forKey: "hasLaunched") || (!settings.showMenuBar && !settings.showDock) {
            UserDefaults.standard.set(true, forKey: "hasLaunched"); showSettings()
        }
        if CommandLine.arguments.contains("--show-shelf") { shelf.show(activate: true) }
    }
    private func applyDockVisibility(_ visible: Bool) {
        // Synchronize both AppKit and the process presentation state. On macOS
        // Tahoe, changing only AppKit's policy can leave the running Dock tile.
        NSApp.setActivationPolicy(visible ? .regular : .accessory)
        var process = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kCurrentProcess))
        let result = TransformProcessType(&process, visible ? ProcessApplicationTransformState(kProcessTransformToForegroundApplication) : ProcessApplicationTransformState(kProcessTransformToUIElementApplication))
        if result != noErr { NSLog("Dropzone: process presentation update failed (%d)", result) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !settings.showMenuBar && !settings.showDock { showSettings() }
        else { shelf.show(activate: true) }
        return true
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard shelf != nil else { sender.reply(toOpenOrPrint: .failure); return }
        shelf.store.add(filenames.map { URL(fileURLWithPath: $0) }); shelf.show()
        sender.reply(toOpenOrPrint: .success)
    }
    @objc private func screensChanged() { activation.screensChanged() }
    @objc func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 530), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = L("Dropzone — настройки"); window.titlebarAppearsTransparent = true
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings, showShelf: { [weak self] in self?.shelf.show(activate: true) }))
            window.isReleasedWhenClosed = false; window.center(); settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    private func showStatusMenu() {
        let menu = NSMenu()
        let entries: [(String, Selector)] = [(L("Показать / скрыть полку"), #selector(toggleShelf)), (L("Очистить полку"), #selector(clearShelf)), (L("Настройки…"), #selector(showSettings)), (L("Завершить Dropzone"), #selector(quit))]
        for (title, action) in entries { let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item) }
        statusItem.menu = menu; statusItem.button?.performClick(nil); statusItem.menu = nil
    }
    @objc private func toggleShelf() { shelf.toggle() }
    @objc private func clearShelf() { shelf.store.clear() }
    @objc private func quit() { NSApp.terminate(nil) }
}

@MainActor final class StatusDropView: NSView {
    var onDrop: (([URL]) -> Void)?
    var onClick: ((NSEvent) -> Void)?
    private var highlighted = false { didSet { needsDisplay = true } }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect); registerForDraggedTypes([.fileURL])
        setAccessibilityElement(true); setAccessibilityRole(.button); setAccessibilityLabel("Dropzone")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func draw(_ dirtyRect: NSRect) {
        if highlighted { NSColor.controlAccentColor.withAlphaComponent(0.3).setFill(); NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill() }

    }
    override func mouseUp(with event: NSEvent) { onClick?(event) }
    override func rightMouseUp(with event: NSEvent) { onClick?(event) }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { highlighted = FileDrag.accepts(sender); return highlighted ? .copy : [] }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { FileDrag.accepts(sender) ? .copy : [] }
    override func draggingExited(_ sender: NSDraggingInfo?) { highlighted = false }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        highlighted = false; guard FileDrag.accepts(sender) else { return false }
        onDrop?(FileDrag.urls(sender.draggingPasteboard)); return true
    }
}
