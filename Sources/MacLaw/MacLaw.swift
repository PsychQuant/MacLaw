import ArgumentParser

@main
struct MacLaw: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maclaw",
        abstract: "macOS-native AI agent runtime",
        version: "0.1.0",
        subcommands: [GatewayCommand.self]
    )
}
