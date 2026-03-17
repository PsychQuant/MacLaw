import Foundation

/// Resolves the active backend from config.
enum BackendRegistry {
    private static let backends: [String: Backend] = [
        "codex": CodexBackend(),
        "claude": ClaudeBackend(),
    ]

    static func resolve(name: String?) -> Backend {
        let key = name ?? "codex"
        return backends[key] ?? CodexBackend()
    }

    static var allNames: [String] { Array(backends.keys).sorted() }
}
