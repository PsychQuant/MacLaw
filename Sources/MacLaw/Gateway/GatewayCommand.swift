import ArgumentParser
import Foundation

struct GatewayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gateway",
        abstract: "Manage the MacLaw gateway",
        subcommands: [GatewayRun.self, GatewayStop.self, GatewayRestart.self, GatewayStatus.self]
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

struct GatewayStop: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the running gateway"
    )

    func run() throws {
        let pids = findGatewayPids()
        if pids.isEmpty {
            print("No running MacLaw gateway found")
            return
        }
        for pid in pids {
            kill(pid, SIGTERM)
        }
        print("Stopped MacLaw gateway (pid \(pids.map(String.init).joined(separator: ", ")))")
    }
}

struct GatewayRestart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restart",
        abstract: "Stop the running gateway and start a new one"
    )

    func run() async throws {
        // Stop existing
        let pids = findGatewayPids()
        if !pids.isEmpty {
            for pid in pids {
                kill(pid, SIGTERM)
            }
            print("Stopped old gateway (pid \(pids.map(String.init).joined(separator: ", ")))")
            // Brief wait for cleanup
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        // Start new
        print("Starting new gateway...")
        let config = try ConfigLoader.load()
        let runner = GatewayRunner(config: config)
        try await runner.run()
    }
}

private func findGatewayPids() -> [Int32] {
    // Use pkill-style broad match: any process with "maclaw" in the command line
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-f", "maclaw"]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let myPid = ProcessInfo.processInfo.processIdentifier
    return output.split(separator: "\n")
        .compactMap { Int32($0) }
        .filter { $0 != myPid }
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
