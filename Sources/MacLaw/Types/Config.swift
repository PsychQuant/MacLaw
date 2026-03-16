import Foundation

struct MacLawConfig: Codable {
    var telegram: TelegramConfig?
    var llm: LLMConfig?
    var cron: CronConfig?
}

struct TelegramConfig: Codable {
    var botToken: String  // @keychain:telegram-bot-token or raw
    var allowFrom: [String]?
    var groupAllowFrom: [String]?
}

struct LLMConfig: Codable {
    var primary: ModelEndpoint?
    var fallback: ModelEndpoint?
}

struct ModelEndpoint: Codable {
    var baseUrl: String
    var apiKey: String?  // @keychain:xxx or raw (nil for keyless endpoints)
    var model: String
    var reasoningEffort: String?
}

struct CronConfig: Codable {
    var jobs: [CronJobConfig]?
}

struct CronJobConfig: Codable {
    var id: String?
    var name: String
    var schedule: String          // "every 1h" or "at 2026-03-17T10:00:00Z"
    var prompt: String
    var model: String?            // override default model
    var deliverTo: String?        // Telegram chat ID
}
