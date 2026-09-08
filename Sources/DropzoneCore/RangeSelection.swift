import Foundation

/// The anchor remains fixed while Shift extends or contracts a range.
public struct RangeSelection {
    private var anchor: String?
    public init() {}
    public mutating func reset() { anchor = nil }
    public mutating func select(_ id: String, orderedIDs: [String], selected: Set<String>, additive: Bool, range: Bool) -> Set<String> {
        guard let end = orderedIDs.firstIndex(of: id) else { return selected }
        if additive {
            anchor = id
            var result = selected
            if !result.insert(id).inserted { result.remove(id) }
            return result
        }
        if range, let anchor, let start = orderedIDs.firstIndex(of: anchor) {
            return Set(orderedIDs[min(start, end)...max(start, end)])
        }
        anchor = id
        return [id]
    }
}
