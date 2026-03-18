import Foundation

/// Manages chat → session mapping per backend. Each backend has its own session file.
actor SessionManager {
    private var sessions: [String: ChatSession] = [:]
    private var currentBackend: String = ""
    private let baseDir: String

    struct ChatSession: Codable {
        var sessionId: String
        var lastActivity: Date
        var messageCount: Int
    }

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.baseDir = "\(home)/.maclaw"
    }

    /// Switch to a backend's session store. Call this when gateway starts.
    func loadForBackend(_ backendName: String) {
        currentBackend = backendName
        let path = stateFilePath(for: backendName)
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            sessions = [:]
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sessions = (try? decoder.decode([String: ChatSession].self, from: data)) ?? [:]
    }

    func getSessionId(forChat chatId: String) -> String? {
        guard let session = sessions[chatId] else { return nil }
        return session.sessionId
    }

    func updateSession(chatId: String, sessionId: String) {
        let existing = sessions[chatId]
        sessions[chatId] = ChatSession(
            sessionId: sessionId,
            lastActivity: Date(),
            messageCount: (existing?.sessionId == sessionId ? (existing?.messageCount ?? 0) : 0) + 1
        )
        saveState()
    }

    func resetSession(forChat chatId: String) {
        sessions.removeValue(forKey: chatId)
        saveState()
    }

    // MARK: - Persistence (per backend)

    private func stateFilePath(for backend: String) -> String {
        "\(baseDir)/sessions-\(backend).json"
    }

    private func saveState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: URL(fileURLWithPath: stateFilePath(for: currentBackend)))
    }
}
