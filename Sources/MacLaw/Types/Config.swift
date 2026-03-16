import Foundation

struct MacLawConfig: Codable {
    var telegram: TelegramConfig?
    var cron: CronConfig?
}

struct TelegramConfig: Codable {
    var botToken: String  // @keychain:telegram-bot-token
    var allowFrom: [String]?
    var groupAllowFrom: [String]?
}

struct CronConfig: Codable {
    var jobs: [CronJobConfig]?
}

struct CronJobConfig: Codable {
    var id: String?
    var name: String
    var schedule: String          // "every 1h" or "at 2026-03-17T10:00:00Z"
    var prompt: String
    var deliverTo: String?        // Telegram chat ID
}
