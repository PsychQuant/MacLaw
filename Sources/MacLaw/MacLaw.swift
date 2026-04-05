import ArgumentParser
import Foundation

@main
struct MacLaw: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maclaw",
        abstract: "macOS-native AI agent runtime",
        version: "0.1.0",
        subcommands: [SetupCommand.self, GatewayCommand.self, BackendCommand.self, SecretsCommand.self, DaemonCommand.self, ActivationCommand.self, PipelineCommand.self]
    )

    // Disable stdout buffering so launchd logs appear immediately
    static func main() async {
        setbuf(stdout, nil)
        setbuf(stderr, nil)
        do {
            var command = try parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            exit(withError: error)
        }
    }
}
