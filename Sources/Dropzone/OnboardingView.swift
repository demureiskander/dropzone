import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var settings: Settings
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Spacer()
                Picker(L("Язык"), selection: $settings.language) {
                    Text("English").tag("en")
                    Text("Русский").tag("ru")
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .accessibilityHidden(true)

            VStack(spacing: 7) {
                Text(L("Добро пожаловать в Dropzone"))
                    .font(.system(size: 30, weight: .bold))
                Text(L("Временная полка для файлов, которая всегда рядом."))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 14) {
                step("cursorarrow.rays", L("Встряхните"), L("Удерживая файл, встряхните курсор — полка появится рядом."))
                step("tray.and.arrow.down", L("Положите"), L("Перетащите файл на полку или к вырезу камеры MacBook."))
                step("arrow.up.forward.app", L("Заберите"), L("Переключитесь в нужное приложение и перетащите файл с полки."))
            }

            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill").foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Локально и приватно")).font(.headline)
                    Text(L("Dropzone не загружает файлы в облако и не собирает аналитику. Оригиналы остаются на месте."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

            Button(L("Начать работу"), action: finish)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(30)
        .frame(width: 720, height: 540)
    }

    private func step(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.blue)
                .frame(height: 30)
            Text(title).font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .top)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
    }
}
