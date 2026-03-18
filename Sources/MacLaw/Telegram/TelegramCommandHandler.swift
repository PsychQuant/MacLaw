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

        // Normalize common typos/aliases
        let normalized = Self.normalizeCommand(cmd)

        switch normalized {
        case "/start":
            return """
            Hi! I'm MacLaw, a macOS-native AI assistant.

            Just send me a message!

            Type /help to see available commands.
            """

        case "/help", "/h":
            return """
            Available commands:

            /help — Show this list
            /status — Gateway status
            /ping — Quick health check
            /model — Show current model
            /model set <name> — Switch model
            /model reset — Use default
            /permissions — Show permission mode
            /permissions safe|full — Toggle
            /reset — Clear session
            /whoami — Your Telegram info
            """

        case "/ping":
            return "pong"

        case "/status", "/stat":
            return await buildStatus()

        case "/model":
            return await handleModel(arg1: arg1, arg2: arg2)

        case "/permissions":
            return await handlePermissions(arg1: arg1)

        case "/reset", "/clear", "/new":
            let chatKey = String(message.chat.id)
            await GatewayRunner.sessionManager.resetSession(forChat: chatKey)
            return "Session cleared. Next message starts a fresh conversation."

        case "/whoami", "/who":
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
            if normalized.hasPrefix("/") {
                return "Unknown command: \(cmd)\nType /help for available commands."
            }
            return nil
        }
    }

    // MARK: - /model

    private static func handleModel(arg1: String?, arg2: String?) async -> String {
        let backend = await GatewayRunner.activeBackend.get()
        let override = await GatewayRunner.currentModel.get()
        let config = backend.readConfigSummary()
        let backendDefault = config["model"]
        let current = override ?? backendDefault ?? "default"
        let source = override != nil ? "(override)" : "(from \(backend.name) config)"

        guard let action = arg1 else {
            // Build full config display
            var lines = [
                "Backend: \(backend.name)",
                "Model: \(current) \(source)",
            ]
            // Show all other config values
            let skipKeys: Set<String> = ["model"]
            for (key, value) in config.sorted(by: { $0.key < $1.key }) {
                if !skipKeys.contains(key) {
                    let displayKey = key.replacingOccurrences(of: "_", with: " ")
                    lines.append("\(displayKey): \(value)")
                }
            }
            lines.append("")
            lines.append("/model set <name> — switch model")
            lines.append("/model reset — use \(backend.name) default")
            return lines.joined(separator: "\n")
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
            return "Model reset to \(backend.name) default (\(backendDefault ?? "default"))"

        default:
            return "Unknown: /model \(action)\nUse /model set <name> or /model reset"
        }
    }

    // MARK: - /permissions

    private static func handlePermissions(arg1: String?) async -> String {
        let current = await GatewayRunner.permissionMode.get()

        guard let action = arg1 else {
            let tools = GatewayRunner.configuredAllowedTools ?? []
            let toolList = tools.isEmpty ? "(none)" : tools.joined(separator: ", ")
            return """
            Permission mode: \(current)

            safe — whitelist only: \(toolList)
            full — all tools, no restrictions

            /permissions safe
            /permissions full
            """
        }

        switch action {
        case "safe":
            await GatewayRunner.permissionMode.set("safe")
            return "Permissions: safe (whitelist only)"
        case "full":
            await GatewayRunner.permissionMode.set("full")
            return "⚠️ Permissions: full (all tools, no restrictions)\nUse /permissions safe to switch back."
        default:
            return "Unknown: /permissions \(action)\nUse: safe or full"
        }
    }

    // MARK: - Command normalization

    /// Maps common typos and aliases to canonical command names.
    private static let aliases: [String: String] = [
        "/permission": "/permissions",
        "/perm": "/permissions",
        "/perms": "/permissions",
        "/stat": "/status",
        "/stats": "/status",
        "/clear": "/reset",
        "/new": "/reset",
        "/who": "/whoami",
        "/h": "/help",
    ]

    private static func normalizeCommand(_ cmd: String) -> String {
        aliases[cmd.lowercased()] ?? cmd.lowercased()
    }

    // MARK: - /status

    private static func buildStatus() async -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let backend = await GatewayRunner.activeBackend.get()
        let override = await GatewayRunner.currentModel.get()
        let model = override ?? backend.readDefaultModel() ?? "default"

        return """
        MacLaw Gateway v0.1.0
        PID: \(ProcessInfo.processInfo.processIdentifier)
        Uptime: \(hours)h \(minutes)m
        Backend: \(backend.name)
        Model: \(model)
        Runtime: Swift + URLSession
        """
    }
}
