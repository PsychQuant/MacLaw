import Foundation

/// Handles Telegram /commands. Returns nil if not a command (pass to LLM).
enum TelegramCommandHandler {

    static func handle(command: String, message: TGMessage, api: TelegramAPI) async -> String? {
        // Strip bot mention: "/help@PsychQuantMacLaw_bot" → "help"
        let cleaned = command
            .trimmingCharacters(in: .whitespaces)
            .split(separator: "@").first.map(String.init) ?? command

        switch cleaned {
        case "/start":
            return """
            👋 Hi! I'm MacLaw, a macOS-native AI assistant.

            I use Codex to answer your questions. Just send me a message!

            Type /help to see available commands.
            """

        case "/help":
            return """
            Available commands:

            /start — Welcome message
            /help — Show this list
            /status — Gateway status (uptime, version)
            /ping — Quick health check
            /model — Current LLM backend info
            /whoami — Your Telegram user info
            """

        case "/ping":
            return "pong 🏓"

        case "/status":
            return buildStatus()

        case "/model":
            return """
            LLM Backend: codex exec (OpenAI Codex CLI)
            Auth: OAuth (via `codex --login`)
            Mode: non-interactive, read-only sandbox
            """

        case "/whoami":
            let user = message.from
            let name = user?.displayName ?? "Unknown"
            let id = user?.id.description ?? "?"
            let username = user.flatMap(\.username).map { "@\($0)" } ?? "none"
            return """
            Name: \(name)
            ID: \(id)
            Username: \(username)
            Chat: \(message.chat.id)
            """

        default:
            // Not a known command
            if cleaned.hasPrefix("/") {
                return "Unknown command: \(cleaned)\nType /help for available commands."
            }
            return nil
        }
    }

    private static func buildStatus() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60

        let version = "0.1.0"
        let pid = ProcessInfo.processInfo.processIdentifier

        return """
        MacLaw Gateway
        Version: \(version)
        PID: \(pid)
        Process uptime: \(hours)h \(minutes)m
        Runtime: macOS-native (Swift + URLSession)
        LLM: codex exec
        """
    }
}
