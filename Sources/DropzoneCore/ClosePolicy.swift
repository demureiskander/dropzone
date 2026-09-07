import Foundation

public enum ClosePolicy {
    public static func requiresConfirmation(count: Int, enabled: Bool, threshold: Int) -> Bool {
        enabled && count > max(1, threshold)
    }
}
