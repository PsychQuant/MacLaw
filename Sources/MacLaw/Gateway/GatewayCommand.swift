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
        let config = try ConfigLoader.loadResolved()
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
        let killed = killAllMacLaw()
        if killed.isEmpty {
            print("No running MacLaw gateway found")
        } else {
            print("Stopped MacLaw gateway (pid \(killed.map(String.init).joined(separator: ", ")))")
        }
    }
}

struct GatewayRestart: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restart",
        abstract: "Stop the running gateway and start a new one"
    )

    func run() async throws {
        let killed = killAllMacLaw()
        if !killed.isEmpty {
            print("Stopped old gateway (pid \(killed.map(String.init).joined(separator: ", ")))")
        }

        // Wait and verify all dead
        for _ in 0..<5 {
            try await Task.sleep(nanoseconds: 500_000_000)
            let remaining = findGatewayPids()
            if remaining.isEmpty { break }
            // Force kill stragglers
            for pid in remaining {
                kill(pid, SIGKILL)
            }
        }

        print("Starting new gateway...")
        let config = try ConfigLoader.loadResolved()
        let runner = GatewayRunner(config: config)
        try await runner.run()
    }
}

/// Kill all maclaw processes except self. SIGTERM first, then SIGKILL after 1s.
@discardableResult
private func killAllMacLaw() -> [Int32] {
    let pids = findGatewayPids()
    guard !pids.isEmpty else { return [] }

    // SIGTERM
    for pid in pids {
        kill(pid, SIGTERM)
    }

    // Wait 1s, then SIGKILL any survivors
    Thread.sleep(forTimeInterval: 1.0)
    let survivors = findGatewayPids()
    for pid in survivors {
        kill(pid, SIGKILL)
    }

    return pids
}

private func findGatewayPids() -> [Int32] {
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
