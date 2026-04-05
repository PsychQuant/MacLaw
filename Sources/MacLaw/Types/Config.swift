import Foundation

struct MacLawConfig: Codable {
    /// AI backend: "codex" (default) or "claude"
    var backend: String?
    /// Tools the backend is allowed to use without prompting (e.g., ["WebSearch", "WebFetch", "Read"])
    var allowedTools: [String]?
    var telegram: TelegramConfig?
    var cron: CronConfig?
    /// Activation layer (replaces cron for new configs)
    var activations: [ActivationConfig]?
    /// Pipeline definitions
    var pipelines: [PipelineConfig]?
    /// Minutes of CPU idle before a backend process is considered stuck and killed (default: 10)
    var livenessIdleMinutes: Int?
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
