import AppKit
import Carbon

@MainActor final class HotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let key = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { key.action?() }
            return noErr
        }, 1, &type, pointer, &handler)
    }
    func register(settings: Settings) {
        if let reference { UnregisterEventHotKey(reference); self.reference = nil }
        settings.shortcutError = nil
        guard settings.shortcutEnabled else { return }
        let id = EventHotKeyID(signature: 0x445A4F4E, id: 1)
        let result = RegisterEventHotKey(settings.shortcutKey, settings.shortcutModifiers, id, GetApplicationEventTarget(), 0, &reference)
        if result != noErr { settings.shortcutError = "Сочетание занято или недоступно. Выберите другое." }
    }
}

struct ShortcutName {
    static func text(key: UInt32, modifiers: UInt32) -> String {
        var prefix = ""
        if modifiers & UInt32(controlKey) != 0 { prefix += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { prefix += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { prefix += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { prefix += "⌘" }
        let names: [UInt32: String] = [49: "Пробел", 0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V", 11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T", 31:"O", 32:"U", 34:"I", 35:"P", 37:"L", 38:"J", 40:"K", 45:"N", 46:"M"]
        return prefix + (names[key] ?? "Клавиша \(key)")
    }
}
