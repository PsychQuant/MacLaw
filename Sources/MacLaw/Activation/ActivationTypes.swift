import Foundation

// MARK: - Activation

enum ActivationType: String, Codable {
    case event
    case schedule
    case interval
}

struct ActivationConfig: Codable {
    let id: String
    let type: ActivationType
    let enabled: Bool?

    // Type-specific fields
    let schedule: String?        // cron expression or "at <ISO8601>"
    let interval: String?        // duration string: "30s", "5m", "1h", "1d"
    let event: EventConfig?      // event source config

    let action: ActionConfig

    var isEnabled: Bool { enabled ?? true }
}

struct EventConfig: Codable {
    let source: EventSource
    let pattern: String          // regex for telegram, path for fswatch

    enum EventSource: String, Codable {
        case telegram
        case fswatch
    }
}

struct ActionConfig: Codable {
    let type: ActionType
    let prompt: String?          // for single task
    let pipeline: String?        // pipeline ID reference

    enum ActionType: String, Codable {
        case task
        case pipeline
    }
}

// MARK: - Activation State

struct ActivationState: Codable {
    var activations: [String: ActivationRunState]
}

struct ActivationRunState: Codable {
    var lastRunAt: String?
    var nextRunAt: String?
    var consecutiveErrors: Int
    var lastError: String?
    var enabled: Bool
    var completed: Bool
}

// MARK: - Activation Context

struct ActivationContext {
    let activationId: String
    let message: String?
    let matchedGroups: [String]
    let filePath: String?

    static func empty(id: String) -> ActivationContext {
        ActivationContext(activationId: id, message: nil, matchedGroups: [], filePath: nil)
    }

    static func telegram(id: String, message: String, groups: [String] = []) -> ActivationContext {
        ActivationContext(activationId: id, message: message, matchedGroups: groups, filePath: nil)
    }

    static func fileWatch(id: String, path: String) -> ActivationContext {
        ActivationContext(activationId: id, message: nil, matchedGroups: [], filePath: path)
    }
}
