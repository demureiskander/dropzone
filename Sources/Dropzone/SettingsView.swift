import SwiftUI
import AppKit
import ServiceManagement
import Carbon

struct SettingsView: View {
    @ObservedObject var settings: Settings
    let showShelf: () -> Void
    @State private var section = 0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text("DROPZONE").font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.top, 24).padding(.bottom, 16)
                nav(L("Активация"), "cursorarrow.rays", 0)
                nav(L("Поведение полки"), "rectangle.on.rectangle", 1)
                nav(L("Основные"), "gearshape", 2)
                Spacer()
                Label("Dropzone", systemImage: "tray.and.arrow.down.fill").font(.headline).padding(.horizontal, 14)
                Text("0.1.0 · Alpha").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(.bottom, 20)
            }.frame(width: 196).padding(.horizontal, 10).background(.quaternary.opacity(0.5))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text([L("Активация"), L("Поведение полки"), L("Основные")][section]).font(.system(size: 26, weight: .bold))
                    Text([L("Полка появляется, когда нужна."), L("Всё под рукой — в удобном ритме."), L("Нативно. Локально. Без ожидания.")][section]).foregroundStyle(.secondary)
                    if section == 0 { activation }
                    else if section == 1 { behavior }
                    else { general }
                }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.frame(width: 740, height: 530)
    }
    private func nav(_ title: String, _ icon: String, _ value: Int) -> some View {
        Button { section = value } label: {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(section == value ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14, content: content).padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }
    private var activation: some View {
        Group {
            card {
                Toggle(L("Вызов встряхиванием"), isOn: $settings.shake).toggleStyle(.switch)
                Text(L("Встряхните курсор, удерживая файлы из Finder.")).font(.caption).foregroundStyle(.secondary)
                Divider()
                Picker(L("Чувствительность"), selection: $settings.sensitivity) {
                    Text(L("Низкая")).tag(0.35); Text(L("Средняя")).tag(1.0); Text(L("Высокая")).tag(1.5)
                }
            }
            card {
                Toggle(L("Перетаскивание на монобровь"), isOn: $settings.notch).toggleStyle(.switch)
                Text(L("Мягкое свечение при приближении. Синяя обводка — можно отпускать файл. Доступно на дисплее с вырезом камеры.")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                Toggle(L("Глобальная горячая клавиша"), isOn: $settings.shortcutEnabled).toggleStyle(.switch)
                ShortcutRecorder(settings: settings).frame(height: 32)
                if let error = settings.shortcutError { Text(L(error)).font(.caption).foregroundStyle(.orange) }
            }
            Button(L("Показать полку"), action: showShelf).buttonStyle(.borderedProminent)
        }
    }
    private var behavior: some View {
        Group {
            card {
                Toggle(L("Следовать за курсором"), isOn: $settings.follow).toggleStyle(.switch)
                Text(L("Полка плавно держится сбоку. При приближении к ней и работе с файлами движение останавливается. Переключатель также есть на самой полке.")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                Toggle(L("Оставлять открытой после передачи"), isOn: $settings.keepOpen).toggleStyle(.switch)
                Text(L("При выключении полка скрывается после принятого перетаскивания. Содержимое сохраняется до закрытия крестиком, очистки или выхода.")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                Toggle(L("Подтверждать закрытие"), isOn: $settings.confirmClose).toggleStyle(.switch)
                Stepper((L("Если элементов больше ") + "\(settings.closeThreshold)"), value: $settings.closeThreshold, in: 1...1000)
                    .disabled(!settings.confirmClose)
                Text(L("Крестик и ⌘W закрывают полку и очищают её. При превышении порога появится вопрос. Оригиналы файлов сохраняются.")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                Label(L("Оригиналы остаются на месте"), systemImage: "doc.on.doc")
                Text(L("Перетаскивание наружу копирует файлы. Очистка полки удаляет только ссылки. Содержимое временное и не восстанавливается после выхода из приложения.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var general: some View {
        Group {
            card {
                Picker(L("Язык"), selection: $settings.language) {
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                }
                Text(L("Применяется сразу.")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                Picker(L("Оформление"), selection: $settings.theme) {
                    Text(L("Системное")).tag("system"); Text(L("Светлое")).tag("light"); Text(L("Тёмное")).tag("dark")
                }
                Divider()
                Toggle(L("Запускать при входе"), isOn: $launchAtLogin).toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginError = SMAppService.mainApp.status == .requiresApproval ? "Подтвердите запуск в Системных настройках → Основные → Объекты входа." : nil
                        } catch { loginError = error.localizedDescription }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                if let loginError { Text(L(loginError)).font(.caption).foregroundStyle(.orange) }
            }
            card {
                Label(L("Все файлы остаются на вашем Mac"), systemImage: "lock.shield")
                Text(L("Нет аналитики, аккаунтов и загрузок в облако. Полка работает без интернета.")).font(.caption).foregroundStyle(.secondary)
            }
            card {
                Text(L("Быстрый старт")).font(.headline)
                Text(L("1. Возьмите файл и встряхните курсор.\n2. Положите его на полку.\n3. Переключитесь в нужное окно и заберите файл."))
                    .font(.system(size: 13)).lineSpacing(6)
                Text(L("Пробел — Quick Look · ⌘A — выбрать всё\nDelete — убрать с полки · ⌘F — следование\n⌘, — настройки (при активной полке, любая раскладка)"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    @ObservedObject var settings: Settings
    func makeNSView(context: Context) -> RecorderButton { RecorderButton(settings: settings) }
    func updateNSView(_ view: RecorderButton, context: Context) { if !view.recording { view.updateTitle() } }
}
@MainActor final class RecorderButton: NSButton {
    let settings: Settings
    var recording = false
    init(settings: Settings) {
        self.settings = settings; super.init(frame: .zero)
        bezelStyle = .rounded; target = self; action = #selector(record); updateTitle()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override var acceptsFirstResponder: Bool { true }
    func updateTitle() { title = ShortcutName.text(key: settings.shortcutKey, modifiers: settings.shortcutModifiers) + L(" — изменить") }
    @objc private func record() { recording = true; title = L("Нажмите сочетание · Esc для отмены"); window?.makeFirstResponder(self) }
    override func resignFirstResponder() -> Bool { recording = false; updateTitle(); return super.resignFirstResponder() }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { recording = false; updateTitle(); return }
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }
        if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        guard modifiers & UInt32(cmdKey | optionKey | controlKey) != 0 else { title = L("Добавьте ⌘, ⌥ или ⌃"); return }
        settings.shortcutKey = UInt32(event.keyCode); settings.shortcutModifiers = modifiers
        recording = false; updateTitle()
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return super.performKeyEquivalent(with: event) }
        keyDown(with: event); return true
    }
}
