import Foundation

/// Handles Telegram /commands. Returns nil if not a command (pass to LLM).
enum TelegramCommandHandler {

    static func handle(command: String, message: TGMessage, api: TelegramAPI) async -> String? {
        // Strip bot mention: "/help@PsychQuantMacLaw_bot" → "/help"
        let cleaned = command
            .trimmingCharacters(in: .whitespaces)
            .split(separator: "@").first.map(String.init) ?? command

        // Handle multi-word commands: "/model set gpt-5.4"
        let parts = cleaned.split(separator: " ", maxSplits: 2)
        let cmd = String(parts[0])
        let arg1 = parts.count > 1 ? String(parts[1]) : nil
        let arg2 = parts.count > 2 ? String(parts[2]) : nil

        switch cmd {
        case "/start":
            return """
            Hi! I'm MacLaw, a macOS-native AI assistant.

            I use Codex to answer your questions. Just send me a message!

            Type /help to see available commands.
            """

        case "/help":
            return """
            Available commands:

            /start — Welcome message
            /help — Show this list
            /status — Gateway status
            /ping — Quick health check
            /model — Show current model
            /model set <name> — Switch model (e.g., gpt-5.4, o3)
            /model reset — Use codex default
            /whoami — Your Telegram user info
            """

        case "/ping":
            return "pong"

        case "/status":
            return await buildStatus()

        case "/model":
            return await handleModel(arg1: arg1, arg2: arg2)

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
            if cmd.hasPrefix("/") {
                return "Unknown command: \(cmd)\nType /help for available commands."
            }
            return nil
        }
    }

    // MARK: - /model

    private static func handleModel(arg1: String?, arg2: String?) async -> String {
        let override = await GatewayRunner.currentModel.get()
        let codexDefault = readCodexDefaultModel()
        let current = override ?? codexDefault ?? "unknown"
        let source = override != nil ? "(override)" : "(from ~/.codex/config.toml)"

        guard let action = arg1 else {
            return """
            Current model: \(current) \(source)
            Backend: codex exec

            /model set <name> — switch model
            /model reset — use codex default (\(codexDefault ?? "unknown"))
            """
        }

        switch action {
        case "set":
            guard let newModel = arg2, !newModel.isEmpty else {
                return "Usage: /model set <name>\nExample: /model set gpt-5.4"
            }
            await GatewayRunner.currentModel.set(newModel)
            return "Model switched to: \(newModel)"

        case "reset":
            await GatewayRunner.currentModel.set(nil)
            return "Model reset to codex default"

        default:
            return "Unknown: /model \(action)\nUse /model set <name> or /model reset"
        }
    }

    /// Read the default model from ~/.codex/config.toml
    private static func readCodexDefaultModel() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.codex/config.toml"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        // Parse: model = "gpt-5.4"
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("model") && trimmed.contains("=") {
                let value = trimmed.split(separator: "=", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                if let v = value, !v.isEmpty {
                    return v
                }
            }
        }
        return nil
    }

    // MARK: - /status

    private static func buildStatus() async -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let override = await GatewayRunner.currentModel.get()
        let model = override ?? readCodexDefaultModel() ?? "unknown"

        return """
        MacLaw Gateway v0.1.0
        PID: \(ProcessInfo.processInfo.processIdentifier)
        Uptime: \(hours)h \(minutes)m
        Model: \(model)
        Runtime: Swift + URLSession
        """
    }
}
