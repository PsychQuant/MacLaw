import ArgumentParser
import Foundation

struct DaemonCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Manage MacLaw as a launchd daemon",
        subcommands: [DaemonInstall.self, DaemonUninstall.self, DaemonStatus.self]
    )
}

private let plistLabel = "ai.psychquant.maclaw"

private var plistPath: String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    return "\(home)/Library/LaunchAgents/\(plistLabel).plist"
}

private func maclawBinaryPath() -> String {
    ProcessInfo.processInfo.arguments.first ?? "/usr/local/bin/maclaw"
}

struct DaemonInstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install and start the MacLaw launchd daemon"
    )

    func run() throws {
        let binary = maclawBinaryPath()
        let logDir = "\(ConfigLoader.configDir)/logs"
        try FileManager.default.createDirectory(atPath: logDir, withIntermediateDirectories: true)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(plistLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binary)</string>
                <string>gateway</string>
                <string>run</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(logDir)/maclaw.stdout.log</string>
            <key>StandardErrorPath</key>
            <string>\(logDir)/maclaw.stderr.log</string>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
            </dict>
        </dict>
        </plist>
        """

        try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)

        // Load the plist
        let load = Process()
        load.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        load.arguments = ["load", plistPath]
        try load.run()
        load.waitUntilExit()

        if load.terminationStatus == 0 {
            print("Daemon installed and started: \(plistLabel)")
            print("Logs: \(logDir)/")
        } else {
            print("Warning: launchctl load exited with status \(load.terminationStatus)")
        }
    }
}

struct DaemonUninstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Stop and remove the MacLaw daemon"
    )

    func run() throws {
        let unload = Process()
        unload.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unload.arguments = ["unload", plistPath]
        try? unload.run()
        unload.waitUntilExit()

        if FileManager.default.fileExists(atPath: plistPath) {
            try FileManager.default.removeItem(atPath: plistPath)
        }

        print("Daemon uninstalled: \(plistLabel)")
    }
}

struct DaemonStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show daemon status"
    )

    func run() throws {
        let installed = FileManager.default.fileExists(atPath: plistPath)

        if !installed {
            print(#"{"ok":true,"data":{"installed":false,"running":false}}"#)
            return
        }

        // Check if running via launchctl list
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["list", plistLabel]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let running = process.terminationStatus == 0

        // Extract PID from launchctl list output
        var pid: Int?
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\"PID\"") || trimmed.contains("PID") {
                let parts = trimmed.components(separatedBy: "=").last?
                    .trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ";", with: "") ?? ""
                pid = Int(parts)
            }
        }

        if let pid {
            print(#"{"ok":true,"data":{"installed":true,"running":true,"pid":\#(pid)}}"#)
        } else {
            print(#"{"ok":true,"data":{"installed":true,"running":\#(running)}}"#)
        }
    }
}
