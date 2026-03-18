import Foundation

struct ClaudeBackend: Backend {
    let name = "claude"
    let cliName = "claude"
    let installHint = "brew install claude"
    let loginHint = "claude login"

    func run(prompt: String, model: String? = nil, sessionId: String? = nil) async throws -> (response: String, sessionId: String?) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = ["claude", "-p", prompt, "--output-format", "text"]
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
                if !stdout.isEmpty {
                    // Claude CLI doesn't support session resume yet
                    continuation.resume(returning: (stdout, nil))
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
        // Claude stores auth in various locations; check if CLI reports logged in
        let result = shellRun("claude auth status 2>&1 | grep -qi 'logged in'")
        if result.exitCode == 0 { return true }
        // Fallback: check if credentials directory exists with files
        let credDir = "\(home)/.claude/credentials"
        return (try? FileManager.default.contentsOfDirectory(atPath: credDir))?.isEmpty == false
    }
}
