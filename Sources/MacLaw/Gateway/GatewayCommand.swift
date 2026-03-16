import ArgumentParser
import Foundation

struct GatewayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gateway",
        abstract: "Manage the MacLaw gateway",
        subcommands: [GatewayRun.self, GatewayStatus.self]
    )
}

struct GatewayRun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Start the gateway"
    )

    @Option(name: .long, help: "Port to bind")
    var port: Int = 18790

    func run() async throws {
        print("MacLaw gateway starting on port \(port)...")
        // TODO: Telegram polling + LLM routing + Cron scheduler
    }
}

struct GatewayStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show gateway status"
    )

    func run() throws {
        print(#"{"ok":true,"status":"not running"}"#)
    }
}
