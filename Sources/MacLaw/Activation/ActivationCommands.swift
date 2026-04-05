import ArgumentParser
import Foundation

struct ActivationCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "activation",
        abstract: "Manage activations (event, schedule, interval)",
        subcommands: [ActivationList.self, ActivationAdd.self, ActivationRm.self]
    )
}

struct ActivationList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all configured activations"
    )

    func run() throws {
        let config = try ConfigLoader.load()
        let activations = config.activations ?? []
        if activations.isEmpty {
            print("No activations configured.")
            return
        }
        for a in activations {
            let status = a.isEnabled ? "enabled" : "disabled"
            let action = a.action.type == .pipeline ? "pipeline:\(a.action.pipeline ?? "?")" : "task"
            print("  \(a.id)  [\(a.type.rawValue)]  \(action)  (\(status))")
        }
    }
}

struct ActivationAdd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new activation"
    )

    @Option(name: .long, help: "Unique activation ID")
    var id: String

    @Option(name: .long, help: "Activation type: event, schedule, interval")
    var type: String

    @Option(name: .long, help: "Schedule (cron expression or 'at <ISO8601>')")
    var schedule: String?

    @Option(name: .long, help: "Interval duration (e.g., '5m', '1h')")
    var interval: String?

    @Option(name: .long, help: "Event source: telegram, fswatch")
    var eventSource: String?

    @Option(name: .long, help: "Event pattern (regex for telegram, path for fswatch)")
    var pattern: String?

    @Option(name: .long, help: "Task prompt (for single-task action)")
    var prompt: String?

    @Option(name: .long, help: "Pipeline ID (for pipeline action)")
    var pipeline: String?

    func run() throws {
        guard let activationType = ActivationType(rawValue: type) else {
            print("Error: Invalid type '\(type)'. Use: event, schedule, interval")
            return
        }

        var event: EventConfig?
        if activationType == .event {
            guard let src = eventSource, let pat = pattern,
                  let source = EventConfig.EventSource(rawValue: src) else {
                print("Error: Event activation requires --event-source and --pattern")
                return
            }
            event = EventConfig(source: source, pattern: pat)
        }

        let actionType: ActionConfig.ActionType = pipeline != nil ? .pipeline : .task
        let action = ActionConfig(type: actionType, prompt: prompt, pipeline: pipeline)

        let activation = ActivationConfig(
            id: id, type: activationType, enabled: true,
            schedule: schedule, interval: interval, event: event,
            action: action
        )

        var config = try ConfigLoader.load()
        var activations = config.activations ?? []
        if activations.contains(where: { $0.id == id }) {
            print("Error: Activation '\(id)' already exists")
            return
        }
        activations.append(activation)
        config.activations = activations
        try saveConfig(config)
        print("Added activation '\(id)' [\(type)]")
    }
}

struct ActivationRm: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rm",
        abstract: "Remove an activation"
    )

    @Argument(help: "Activation ID to remove")
    var id: String

    func run() throws {
        var config = try ConfigLoader.load()
        var activations = config.activations ?? []
        guard activations.contains(where: { $0.id == id }) else {
            print("Error: Activation '\(id)' not found")
            return
        }
        activations.removeAll { $0.id == id }
        config.activations = activations
        try saveConfig(config)
        print("Removed activation '\(id)'")
    }
}

// MARK: - Config save helper

private func saveConfig(_ config: MacLawConfig) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(config)
    try data.write(to: URL(fileURLWithPath: ConfigLoader.configPath))
}
