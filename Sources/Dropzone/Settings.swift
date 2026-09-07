import AppKit
import Combine
import Carbon

@MainActor final class Settings: ObservableObject {
    static let shared = Settings()
    @Published var language: String { didSet { save(language, "language") } }
    @Published var follow: Bool { didSet { save(follow, "follow") } }
    @Published var shake: Bool { didSet { save(shake, "shake") } }
    @Published var notch: Bool { didSet { save(notch, "notch") } }
    @Published var confirmClose: Bool { didSet { save(confirmClose, "confirmClose") } }
    @Published var closeThreshold: Int { didSet { save(closeThreshold, "closeThreshold") } }
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
            "language": "en", "confirmClose": true, "closeThreshold": 5, "sensitivity": 1.0, "theme": "system", "shortcutEnabled": true,
            "shortcutKey": Int(kVK_Space), "shortcutModifiers": Int(optionKey | shiftKey)])
        language = defaults.string(forKey: "language") == "ru" ? "ru" : "en"
        confirmClose = defaults.bool(forKey: "confirmClose")
        closeThreshold = min(max(defaults.integer(forKey: "closeThreshold"), 1), 1000)
        follow = defaults.bool(forKey: "follow"); shake = defaults.bool(forKey: "shake")
        notch = defaults.bool(forKey: "notch"); keepOpen = defaults.bool(forKey: "keepOpen")
        let savedSensitivity = defaults.double(forKey: "sensitivity")
        sensitivity = savedSensitivity == 0.7 ? 0.35 : savedSensitivity
        if savedSensitivity == 0.7 { defaults.set(0.35, forKey: "sensitivity") }
         theme = defaults.string(forKey: "theme") ?? "system"
        shortcutKey = UInt32(defaults.integer(forKey: "shortcutKey"))
        shortcutModifiers = UInt32(defaults.integer(forKey: "shortcutModifiers"))
        shortcutEnabled = defaults.bool(forKey: "shortcutEnabled")
    }
    func applyTheme() {
        NSApp.appearance = theme == "system" ? nil : NSAppearance(named: theme == "dark" ? .darkAqua : .aqua)
    }
}
