import AppKit
import SwiftUI
import DropzoneCore
import QuickLookThumbnailing
import UniformTypeIdentifiers

struct ShelfView: View {
    @ObservedObject var store: ShelfStore
    @ObservedObject var settings: Settings
    let controller: ShelfController
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var surface: Color { scheme == .dark ? Color(white: 0.065) : Color(white: 0.96) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.loading { ProgressView().controlSize(.small).padding(6) }
            if store.expanded { detail } else { compact }
            if let error = store.error {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    Text(error).font(.caption).lineLimit(3)
                    Button { store.error = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                }.padding(10).background(.orange.opacity(0.09)).padding(10)
            }
        }
        .background(surface.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(store.hovering ? Color.accentColor : Color.primary.opacity(0.22), lineWidth: store.hovering ? 3 : 1))
        .padding(3)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: store.hovering)
        .onExitCommand { controller.hide() }
    }
    private var header: some View {
        HStack(spacing: 8) {
            roundButton(store.expanded ? "chevron.left" : "xmark", label: store.expanded ? "Свернуть" : "Скрыть полку") {
                if store.expanded { controller.setExpanded(false) } else { controller.hide() }
            }
            if store.expanded {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.countLabel).font(.system(size: 15, weight: .semibold))
                    Text(store.sizeLabel).font(.system(size: 11)).foregroundStyle(.secondary)
                }.lineLimit(1)
            }
            Spacer(minLength: 0)
            if store.expanded {
                roundButton(store.list ? "square.grid.2x2" : "list.bullet", label: store.list ? "Показать сетку" : "Показать список") { store.list.toggle() }
            }
            roundButton(settings.follow ? "cursorarrow.motionlines" : "cursorarrow", label: settings.follow ? "Следование включено — выключить" : "Следование выключено — включить", active: settings.follow) {
                settings.follow.toggle()
            }
            roundButton("ellipsis", label: "Действия с файлами") { controller.showMenu() }
                .background(MenuAnchor { controller.menuAnchor = $0 })
        }
        .padding(.horizontal, 14).padding(.top, 17).padding(.bottom, 8)
        .overlay(alignment: .top) {
            Capsule().fill(Color.primary.opacity(0.28)).frame(width: 34, height: 4).padding(.top, 8)
                .frame(width: 80, height: 16).overlay(WindowHandle { store.interaction = $0 })
        }
    }
    private var compact: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 4)
            if let first = store.items.first {
                ZStack {
                    if store.items.count > 1 {
                        RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.22))
                            .frame(width: 80, height: 100).rotationEffect(.degrees(-12)).offset(x: -9, y: 1)
                    }
                    FileThumbnail(url: first.url, size: 100)
                        .opacity(first.available ? 1 : 0.35)
                }
                .frame(maxWidth: .infinity, minHeight: 112)
                .overlay(interaction(nil))
                .accessibilityLabel("Перетащить все файлы")
                .accessibilityAction(named: Text("Открыть список файлов")) { controller.setExpanded(true) }
                Button { controller.setExpanded(true) } label: {
                    HStack(spacing: 5) {
                        Text(store.title).lineLimit(1).truncationMode(.middle)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                    }.font(.system(size: 12, weight: .medium)).padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }.buttonStyle(.plain).padding(.horizontal, 18)
            } else {
                Image(systemName: store.hovering ? "arrow.down.doc.fill" : "tray.and.arrow.down")
                    .font(.system(size: 36, weight: .light)).foregroundStyle(store.hovering ? Color.accentColor : .secondary)
                Text(store.hovering ? "Отпустите файлы" : "Перетащите сюда")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text("Встряхните файл · положите · заберите")
                    .font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 10)
        }.frame(maxWidth: .infinity).padding(.bottom, 12)
    }
    private var detail: some View {
        ScrollView {
            if store.list {
                LazyVStack(spacing: 5) {
                    ForEach(store.items) { item in
                        HStack(spacing: 10) {
                            FileThumbnail(url: item.url, size: 28)
                            Text(item.name).font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(item.available ? (item.isDirectory ? "Папка" : ByteCountFormatter.string(fromByteCount: item.byteSize, countStyle: .file)) : "Недоступен")
                                .font(.system(size: 11)).foregroundStyle(item.available ? Color.secondary : .orange)
                        }.padding(9).background(selectionColor(item), in: RoundedRectangle(cornerRadius: 9))
                            .overlay(interaction(item.id)).accessibilityElement(children: .combine)
                            .accessibilityAction { store.select(item.id, additive: false) }
                    }
                }.padding(12)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 12) {
                    ForEach(store.items) { item in
                        VStack(spacing: 8) {
                            FileThumbnail(url: item.url, size: 65).opacity(item.available ? 1 : 0.35)
                            Text(item.name).font(.system(size: 12)).lineLimit(2).truncationMode(.middle).multilineTextAlignment(.center)
                            if !item.available { Text("Недоступен").font(.caption2).foregroundStyle(.orange) }
                        }.frame(maxWidth: .infinity, minHeight: 118).padding(8)
                            .background(selectionColor(item), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(interaction(item.id)).accessibilityElement(children: .combine)
                            .accessibilityAction { store.select(item.id, additive: false) }
                    }
                }.padding(14)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func selectionColor(_ item: FileReference) -> Color {
        store.selection.contains(item.id) ? Color.accentColor.opacity(0.20) : .clear
    }
    private func interaction(_ id: String?) -> some View {
        FileInteraction(id: id, store: store, onDoubleClick: { controller.reveal() },
            onContext: { controller.showMenu(event: $0) }, onDragEnd: { operation in
                if operation != [], !settings.keepOpen { controller.hide() }
            })
    }
    private func roundButton(_ symbol: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.85))
                .frame(width: 30, height: 30)
                .background(active ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.07), in: Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.05)))
        }.buttonStyle(.plain).help(label).accessibilityLabel(label)
    }
}

struct FileThumbnail: View {
    let url: URL
    let size: CGFloat
    @State private var image: NSImage?
    var body: some View {
        Image(nsImage: image ?? NSWorkspace.shared.icon(forFile: url.path))
            .resizable().interpolation(.high).scaledToFit().frame(width: size, height: size)
            .task(id: url) {
                image = nil
                // A Quick Look thumbnail of an empty text file is a blank page. Finder's
                // document icon remains recognizable; use real thumbnails only for media.
                let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
                guard let type, type.conforms(to: .image) || type.conforms(to: .movie) else { return }
                let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: size, height: size), scale: 2, representationTypes: .thumbnail)
                do {
                    let result = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                    guard !Task.isCancelled else { return }
                    image = result.nsImage
                } catch { /* The system file icon remains a valid preview. */ }
            }
    }
}

private struct MenuAnchor: NSViewRepresentable {
    let register: (NSView) -> Void
    func makeNSView(context: Context) -> NSView {
        let view = PassiveAnchorView()
        register(view)
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { register(nsView) }
}
private final class PassiveAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
