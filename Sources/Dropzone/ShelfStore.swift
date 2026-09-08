import AppKit
import DropzoneCore
import Combine

@MainActor final class ShelfStore: ObservableObject {
    @Published var items: [FileReference] = []
    @Published var selection: Set<String> = []
    @Published var expanded = false
    @Published var list = false
    @Published var hovering = false
    @Published var loading = false
    @Published var error: String?
    var interaction = false
    var exporting = false
    var menuOpen = false
    private var generation = 0
    private var rangeSelection = RangeSelection()
    private var importingURLs: [URL] = []
    var closeItemCount: Int {
        Set((items.map(\.url) + importingURLs + importQueue).map { $0.standardizedFileURL }).count
    }
    private var importQueue: [URL] = []
    var chosen: [FileReference] { selection.isEmpty ? items : items.filter { selection.contains($0.id) } }
    var countLabel: String {
        let n = items.count
        if Settings.shared.language != "ru" { return "\(n) " + (n == 1 ? "file" : "files") }
        let word = (11...14).contains(n % 100) ? "файлов" : n % 10 == 1 ? "файл" : (2...4).contains(n % 10) ? "файла" : "файлов"
        return "\(n) \(word)"
    }
    var title: String { items.count == 1 ? items[0].name : countLabel }
    var sizeLabel: String {
        let bytes = items.filter { !$0.isDirectory }.reduce(Int64(0)) { $0 + $1.byteSize }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) + (items.contains { $0.isDirectory } ? L(" · без содержимого папок") : "")
    }

    func add(_ urls: [URL]) {
        importQueue += urls.filter(\.isFileURL)
        guard !loading else { return }
        processQueue()
    }
    private func processQueue() {
        guard !importQueue.isEmpty else { loading = false; return }
        loading = true
        let urls = importQueue
        importingURLs = urls
        importQueue = []
        let version = generation
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> ([FileReference], [String]) in
                var files: [FileReference] = []; var errors: [String] = []
                for url in urls {
                    do { files.append(try FileReference(url: url)) }
                    catch { errors.append(url.lastPathComponent) }
                }
                return (files, errors)
            }.value
            guard version == generation else { return }
            importingURLs = []
            var inventory = ShelfInventory()
            inventory.append(items); inventory.append(result.0)
            items = inventory.items
            if !result.1.isEmpty { error = "Не удалось прочитать: " + result.1.prefix(3).joined(separator: ", ") }
            processQueue()
        }
    }
    func refresh() {
        let snapshot = items
        Task {
            let refreshed = await Task.detached { snapshot.map { $0.refreshed() } }.value
            let updates = Dictionary(uniqueKeysWithValues: refreshed.map { ($0.id, $0) })
            items = items.map { updates[$0.id] ?? $0 }
        }
    }
    func clear() {
        generation += 1; importingURLs = []; importQueue = []; loading = false
        items = []; selection = []; error = nil; rangeSelection.reset()
    }
    func removeSelection() {
        let ids = Set(chosen.map(\.id))
        remove(ids: ids)
    }
    func remove(ids: Set<String>) {
        items.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        if items.isEmpty { rangeSelection.reset() }
    }
    func select(_ id: String, additive: Bool, range: Bool = false) {
        selection = rangeSelection.select(id, orderedIDs: items.map(\.id), selected: selection, additive: additive, range: range)
    }
    func selectAll() { selection = Set(items.map(\.id)) }
    func clearSelection() { selection = []; rangeSelection.reset() }
    func validURLs() -> [URL] {
        let refreshed = chosen.map { $0.refreshed() }
        if refreshed.contains(where: { !$0.available }) { error = "Некоторые файлы недоступны. Проверьте оригиналы в Finder." }
        return refreshed.filter(\.available).map(\.url)
    }

    func exportPayload() -> (urls: [URL], ids: Set<String>) {
        let refreshed = chosen.map { $0.refreshed() }
        if refreshed.contains(where: { !$0.available }) { error = "Некоторые файлы недоступны. Проверьте оригиналы в Finder." }
        let available = refreshed.filter(\.available)
        return (available.map(\.url), Set(available.map(\.id)))
    }
}
