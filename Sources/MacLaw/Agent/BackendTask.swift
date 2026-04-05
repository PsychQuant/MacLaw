import Foundation

/// Represents a spawned backend process that runs independently of the gateway.
struct BackendTask: Sendable {
    let id: String
    let pid: Int32
    let chatId: Int64
    let prompt: String
    let outputFile: String
    let stderrFile: String
    let startedAt: Date
    let isGroupChat: Bool
    let sessionId: String?

    /// Check if the process is still running.
    var isRunning: Bool {
        kill(pid, 0) == 0
    }

    /// Get CPU usage percentage for this process (0.0 - 100.0+).
    var cpuUsage: Double {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-p", "\(pid)", "-o", "%cpu="]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return -1
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let value = Double(str) else { return -1 }
        return value
    }

    /// Read the output file contents (if process has finished writing).
    func readOutput() -> String? {
        guard let data = try? String(contentsOfFile: outputFile, encoding: .utf8) else { return nil }
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Kill the process.
    func terminate() {
        kill(pid, SIGTERM)
        // Give it 2 seconds, then force kill
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            kill(self.pid, SIGKILL)
        }
    }

    /// Clean up temporary files.
    func cleanup() {
        try? FileManager.default.removeItem(atPath: outputFile)
        try? FileManager.default.removeItem(atPath: stderrFile)
    }
}
