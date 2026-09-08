public enum DragCompletion {
    public static func shouldRemove(succeeded: Bool, returnedToShelf: Bool) -> Bool {
        succeeded && !returnedToShelf
    }

    public static func shouldHide(succeeded: Bool, remainingCount: Int, keepOpen: Bool) -> Bool {
        succeeded && remainingCount == 0 && !keepOpen
    }
}
