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

    func run() async throws {
        let config = try ConfigLoader.load()
        let runner = GatewayRunner(config: config)
        try await runner.run()
    }
}

struct GatewayStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show gateway status"
    )

    func run() throws {
        // Check if maclaw gateway process is running
        let result = processCheck("maclaw.*gateway")
        let json: String
        if let pid = result {
            json = #"{"ok":true,"data":{"running":true,"pid":\#(pid)}}"#
        } else {
            json = #"{"ok":true,"data":{"running":false}}"#
        }
        print(json)
    }

    private func processCheck(_ pattern: String) -> Int? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", pattern]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.split(separator: "\n").compactMap { Int($0) }.first
    }
}
