import ArgumentParser

@main
struct MacLaw: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maclaw",
        abstract: "macOS-native AI agent runtime",
        version: "0.1.0",
        subcommands: [GatewayCommand.self, SecretsCommand.self, DaemonCommand.self]
    )
}
