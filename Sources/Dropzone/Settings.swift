import AppKit
import Combine
import Carbon

@MainActor final class Settings: ObservableObject {
    static let shared = Settings()
    @Published var follow: Bool { didSet { save(follow, "follow") } }
    @Published var shake: Bool { didSet { save(shake, "shake") } }
    @Published var notch: Bool { didSet { save(notch, "notch") } }
    @Published var keepOpen: Bool { didSet { save(keepOpen, "keepOpen") } }
    @Published var sensitivity: Double { didSet { save(sensitivity, "sensitivity") } }
    @Published var theme: String { didSet { save(theme, "theme"); applyTheme() } }
    @Published var shortcutKey: UInt32 { didSet { save(Int(shortcutKey), "shortcutKey") } }
    @Published var shortcutModifiers: UInt32 { didSet { save(Int(shortcutModifiers), "shortcutModifiers") } }
    @Published var shortcutEnabled: Bool { didSet { save(shortcutEnabled, "shortcutEnabled") } }
    @Published var shortcutError: String?
    private let defaults = UserDefaults.standard
    private func save(_ value: Any, _ key: String) { defaults.set(value, forKey: key) }
    private init() {
        defaults.register(defaults: ["follow": true, "shake": true, "notch": true, "keepOpen": false,
            "sensitivity": 1.0, "theme": "system", "shortcutEnabled": true,
            "shortcutKey": Int(kVK_Space), "shortcutModifiers": Int(optionKey | shiftKey)])
        follow = defaults.bool(forKey: "follow"); shake = defaults.bool(forKey: "shake")
        notch = defaults.bool(forKey: "notch"); keepOpen = defaults.bool(forKey: "keepOpen")
        sensitivity = defaults.double(forKey: "sensitivity"); theme = defaults.string(forKey: "theme") ?? "system"
        shortcutKey = UInt32(defaults.integer(forKey: "shortcutKey"))
        shortcutModifiers = UInt32(defaults.integer(forKey: "shortcutModifiers"))
        shortcutEnabled = defaults.bool(forKey: "shortcutEnabled")
    }
    func applyTheme() {
        NSApp.appearance = theme == "system" ? nil : NSAppearance(named: theme == "dark" ? .darkAqua : .aqua)
    }
}
