import Foundation

/// Manages chat → codex session mapping with timeout-based rotation.
actor SessionManager {
    private var sessions: [String: ChatSession] = [:]
    private let stateFile: String
    private let timeoutSeconds: TimeInterval

    struct ChatSession: Codable {
        var sessionId: String
        var lastActivity: Date
        var messageCount: Int
    }

    init(timeoutMinutes: Int = 30) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.stateFile = "\(home)/.maclaw/sessions.json"
        self.timeoutSeconds = TimeInterval(timeoutMinutes * 60)
        // Load state synchronously from file
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "\(home)/.maclaw/sessions.json")) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.sessions = (try? decoder.decode([String: ChatSession].self, from: data)) ?? [:]
        }
    }

    /// Get the session ID for a chat, or nil if a new session should be started.
    func getSessionId(forChat chatId: String) -> String? {
        guard let session = sessions[chatId] else { return nil }
        // No timeout — codex manages its own context window.
        // Use /reset to manually start a new session.
        return session.sessionId
    }

    /// Record a new or resumed session.
    func updateSession(chatId: String, sessionId: String) {
        let existing = sessions[chatId]
        sessions[chatId] = ChatSession(
            sessionId: sessionId,
            lastActivity: Date(),
            messageCount: (existing?.sessionId == sessionId ? (existing?.messageCount ?? 0) : 0) + 1
        )
        saveState()
    }

    /// Force reset a chat's session (via /reset command).
    func resetSession(forChat chatId: String) {
        sessions.removeValue(forKey: chatId)
        saveState()
    }

    // MARK: - Persistence

    private func loadState() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFile)) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        sessions = (try? decoder.decode([String: ChatSession].self, from: data)) ?? [:]
    }

    private func saveState() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: URL(fileURLWithPath: stateFile))
    }
}
