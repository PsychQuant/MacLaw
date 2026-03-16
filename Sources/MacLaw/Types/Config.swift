import Foundation

struct MacLawConfig: Codable {
    var telegram: TelegramConfig?
    var cron: CronConfig?
}

struct TelegramConfig: Codable {
    var botToken: String
    /// DM policy: "open" (default), "allowlist", "disabled"
    var dmPolicy: String?
    /// Group policy: "open" (default), "allowlist", "disabled"
    var groupPolicy: String?
    /// Allowed user IDs for DM (when dmPolicy = "allowlist")
    var allowFrom: [String]?
    /// Allowed user IDs for groups (when groupPolicy = "allowlist")
    var groupAllowFrom: [String]?
    /// Require @mention in groups to respond
    var requireMention: Bool?
    /// Bot username (for @mention detection, without @)
    var botUsername: String?
}

struct CronConfig: Codable {
    var jobs: [CronJobConfig]?
}

struct CronJobConfig: Codable {
    var id: String?
    var name: String
    var schedule: String
    var prompt: String
    var deliverTo: String?
}
