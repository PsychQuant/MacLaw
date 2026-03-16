import Foundation

enum AccessControl {

    enum Decision {
        case allowed
        case denied(reason: String)
        case ignored  // silently ignore (e.g., group message without @mention)
    }

    static func check(message: TGMessage, config: TelegramConfig) -> Decision {
        let senderId = message.from?.id.description ?? ""
        let isGroup = message.chat.type != "private"

        if isGroup {
            return checkGroup(message: message, senderId: senderId, config: config)
        } else {
            return checkDM(senderId: senderId, config: config)
        }
    }

    // MARK: - DM

    private static func checkDM(senderId: String, config: TelegramConfig) -> Decision {
        let policy = config.dmPolicy ?? "open"

        switch policy {
        case "disabled":
            return .denied(reason: "DM is disabled")

        case "allowlist":
            let allowed = config.allowFrom ?? []
            if allowed.isEmpty || allowed.contains("*") {
                return .allowed
            }
            if allowed.contains(senderId) {
                return .allowed
            }
            return .denied(reason: "You are not in the allowed list")

        default: // "open"
            return .allowed
        }
    }

    // MARK: - Group

    private static func checkGroup(message: TGMessage, senderId: String, config: TelegramConfig) -> Decision {
        let policy = config.groupPolicy ?? "open"

        switch policy {
        case "disabled":
            return .ignored

        case "allowlist":
            let allowed = config.groupAllowFrom ?? config.allowFrom ?? []
            if !allowed.isEmpty && !allowed.contains("*") && !allowed.contains(senderId) {
                return .ignored
            }

        default: // "open"
            break
        }

        // Check requireMention
        if config.requireMention == true {
            guard let text = message.text else { return .ignored }
            let botName = config.botUsername ?? "PsychQuantMacLaw_bot"
            if !text.contains("@\(botName)") {
                return .ignored
            }
        }

        return .allowed
    }
}
