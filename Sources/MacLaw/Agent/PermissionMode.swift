import Foundation

/// Thread-safe runtime permission mode, switchable via /permissions.
actor PermissionMode {
    private var mode: String = "safe"
    func get() -> String { mode }
    func set(_ newMode: String) { mode = newMode }
}
