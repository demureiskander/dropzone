import Foundation

public struct FileReference: Identifiable, Equatable, Sendable {
    public let id: String
    public var url: URL
    public let bookmark: Data?
    public var byteSize: Int64
    public var isDirectory: Bool
    public var available: Bool
    public var name: String { url.lastPathComponent }

    public init(url: URL) throws {
        let canonical = url.standardizedFileURL.resolvingSymlinksInPath()
        let info = try canonical.resourceValues(forKeys: [.fileResourceIdentifierKey, .volumeIdentifierKey, .fileSizeKey, .isDirectoryKey])
        self.url = canonical
        if let fileID = info.fileResourceIdentifier, let volumeID = info.volumeIdentifier {
            id = "\(volumeID):\(fileID)"
        } else { id = canonical.path }
        bookmark = try? canonical.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        byteSize = Int64(info.fileSize ?? 0)
        isDirectory = info.isDirectory ?? false
        available = true
    }

    public func refreshed() -> FileReference {
        var copy = self
        if let bookmark {
            var stale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale) {
                copy.url = resolved
            }
        }
        copy.available = FileManager.default.fileExists(atPath: copy.url.path)
        if let values = try? copy.url.resourceValues(forKeys: [.fileSizeKey]) { copy.byteSize = Int64(values.fileSize ?? 0) }
        return copy
    }
}

public struct ShelfInventory: Sendable {
    public private(set) var items: [FileReference] = []
    public init() {}
    public mutating func append(_ incoming: [FileReference]) {
        var known = Set(items.map(\.id))
        for file in incoming where known.insert(file.id).inserted { items.append(file) }
    }
    public mutating func remove(ids: Set<String>) { items.removeAll { ids.contains($0.id) } }
    public mutating func clear() { items.removeAll() }
}
