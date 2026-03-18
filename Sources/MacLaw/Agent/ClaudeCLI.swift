import Foundation

struct ClaudeBackend: Backend {
    let name = "claude"
    let cliName = "claude"
    let installCommand = "curl -fsSL https://claude.ai/install.sh | bash"
    let installHint = "curl -fsSL https://claude.ai/install.sh | bash"
    let loginHint = "claude login"

    private static let groupSchema = """
    {"type":"object","properties":{"shouldRespond":{"type":"boolean"},"response":{"type":"string"}},"required":["shouldRespond"]}
    """

    func run(prompt: String, model: String? = nil, sessionId: String? = nil, isGroupChat: Bool = false, allowedTools: [String]? = nil) async throws -> (response: String?, sessionId: String?, shouldRespond: Bool) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.currentDirectoryURL = URL(fileURLWithPath: "\(FileManager.default.homeDirectoryForCurrentUser.path)/.maclaw/workspace")
        var args = ["claude", "-p", prompt, "--output-format", "json"]
        if let tools = allowedTools, !tools.isEmpty {
            for tool in tools {
                args += ["--allowedTools", tool]
            }
        } else if allowedTools == nil {
            // Full mode — no restrictions
            args += ["--dangerously-skip-permissions"]
        }
        if let sid = sessionId {
            args += ["--resume", sid]
        }
        if let model {
            args += ["--model", model]
        }
        if isGroupChat {
            args += ["--json-schema", Self.groupSchema]
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

                let parsed = Self.parseOutput(stdout, isGroupChat: isGroupChat)

                if !parsed.shouldRespond {
                    // AI decided not to respond (group chat structured output)
                    continuation.resume(returning: (nil, parsed.sessionId, false))
                } else if proc.terminationStatus != 0 && (parsed.response == nil || parsed.response!.isEmpty) {
                    // Non-zero exit with no output = real error
                    let error = stderr.isEmpty ? "claude exited with status \(proc.terminationStatus)" : stderr
                    continuation.resume(throwing: BackendError.executionFailed(error))
                } else {
                    // Normal response (may be empty — that's OK, not an error)
                    continuation.resume(returning: (parsed.response, parsed.sessionId, true))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: BackendError.launchFailed(error.localizedDescription))
            }
        }
    }

    private static func parseOutput(_ output: String, isGroupChat: Bool) -> (response: String?, sessionId: String?, shouldRespond: Bool) {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (output.isEmpty ? nil : output, nil, true)
        }

        let sessionId = json["session_id"] as? String

        if isGroupChat, let structured = json["structured_output"] as? [String: Any] {
            let shouldRespond = structured["shouldRespond"] as? Bool ?? true
            let response = structured["response"] as? String
            return (response, sessionId, shouldRespond)
        }

        // Non-group or no structured output: use result field
        let text = json["result"] as? String
        return (text, sessionId, true)
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
