import Foundation

/// Sends Telegram messages with automatic chunking for long texts.
enum TelegramSender {
    private static let maxLength = 4096

    static func send(api: TelegramAPI, chatId: Int64, text: String) async throws {
        let chunks = splitMessage(text, maxLength: maxLength)
        for chunk in chunks {
            try await api.sendMessage(chatId: chatId, text: chunk)
        }
    }

    static func splitMessage(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var chunks: [String] = []
        var remaining = text

        while remaining.count > maxLength {
            let prefix = remaining.prefix(maxLength)
            // Find last newline to split cleanly
            if let lastNewline = prefix.lastIndex(of: "\n") {
                let splitIndex = remaining.index(after: lastNewline)
                chunks.append(String(remaining[..<lastNewline]))
                remaining = String(remaining[splitIndex...])
            } else {
                // No newline found — hard cut
                let splitIndex = remaining.index(remaining.startIndex, offsetBy: maxLength)
                chunks.append(String(remaining[..<splitIndex]))
                remaining = String(remaining[splitIndex...])
            }
        }

        if !remaining.isEmpty {
            chunks.append(remaining)
        }

        return chunks
    }
}
