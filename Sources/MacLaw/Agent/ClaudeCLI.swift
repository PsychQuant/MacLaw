import Foundation

struct ClaudeBackend: Backend {
    let name = "claude"
    let cliName = "claude"
    let installCommand = "curl -fsSL https://claude.ai/install.sh | bash"
    let installHint = "curl -fsSL https://claude.ai/install.sh | bash"
    let loginHint = "claude login"

    func run(prompt: String, model: String? = nil, sessionId: String? = nil) async throws -> (response: String, sessionId: String?) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["claude", "-p", prompt, "--output-format", "json"]
        if let sid = sessionId {
            args += ["--resume", sid]
        }
        if let model {
            args += ["--model", model]
        }
        process.arguments = args
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? ""
        let extraPaths = ["/usr/local/bin", "/opt/homebrew/bin", "\(home)/Library/pnpm", "\(home)/.local/bin"]
        env["PATH"] = (extraPaths + [env["PATH"] ?? ""]).joined(separator: ":")
        process.environment = env

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                // Parse JSON output to get session_id and result text
                let (text, newSessionId) = Self.parseJsonOutput(stdout)

                if let text, !text.isEmpty {
                    continuation.resume(returning: (text, newSessionId))
                } else {
                    let error = stderr.isEmpty ? "claude exited with status \(proc.terminationStatus)" : stderr
                    continuation.resume(throwing: BackendError.executionFailed(error))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BackendError.launchFailed(error.localizedDescription))
            }
        }
    }

    /// Parse claude -p --output-format json output.
    /// Format: {"type":"result","subtype":"success","session_id":"uuid","result":"text",...}
    private static func parseJsonOutput(_ output: String) -> (text: String?, sessionId: String?) {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Fallback: treat as plain text
            return (output.isEmpty ? nil : output, nil)
        }
        let text = json["result"] as? String
        let sessionId = json["session_id"] as? String
        return (text, sessionId)
    }

    func readDefaultModel() -> String? {
        readConfigSummary()["model"]
    }

    func readConfigSummary() -> [String: String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(home)/.claude/settings.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in json {
            if let str = value as? String {
                result[key] = str
            } else if let bool = value as? Bool {
                result[key] = bool ? "true" : "false"
            }
        }
        return result
    }

    func isAuthenticated() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let result = shellRun("claude auth status 2>&1 | grep -qi 'logged in'")
        if result.exitCode == 0 { return true }
        let credDir = "\(home)/.claude/credentials"
        return (try? FileManager.default.contentsOfDirectory(atPath: credDir))?.isEmpty == false
    }
}
