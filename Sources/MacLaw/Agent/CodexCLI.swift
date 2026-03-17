import Foundation

struct CodexBackend: Backend {
    let name = "codex"
    let cliName = "codex"
    let installHint = "brew install codex"
    let loginHint = "codex --login"

    private let systemPrompt = """
        You are a helpful AI assistant running as a Telegram chatbot called MacLaw. \
        Respond conversationally in the user's language. \
        Do NOT read files, run commands, or act as a code agent. \
        Just answer the user's question directly and concisely.
        """

    func run(prompt: String, model: String? = nil, sessionId: String? = nil) async throws -> (response: String, sessionId: String?) {
        let outputFile = NSTemporaryDirectory() + "maclaw-codex-\(UUID().uuidString).txt"
        defer { try? FileManager.default.removeItem(atPath: outputFile) }

        let process = Process()
        let stdoutPipe = Pipe()  // Need stdout for --json to get thread_id
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args: [String]
        if let sid = sessionId {
            // Resume existing session
            args = ["codex", "exec", "resume", sid, prompt,
                    "-o", outputFile, "--skip-git-repo-check", "--json"]
        } else {
            // New session
            let fullPrompt = "\(systemPrompt)\n\nUser message: \(prompt)"
            args = ["codex", "exec", fullPrompt,
                    "--sandbox", "read-only", "--skip-git-repo-check",
                    "-o", outputFile, "--json"]
        }
        if let model {
            args += ["-m", model]
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
                let output = (try? String(contentsOfFile: outputFile, encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                // Extract thread_id from JSON stdout
                let threadId = Self.extractThreadId(from: stdout)

                if !output.isEmpty {
                    continuation.resume(returning: (output, threadId))
                } else {
                    let error = stderr.isEmpty ? "codex exited with status \(proc.terminationStatus)" : stderr
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

    private static func extractThreadId(from jsonLines: String) -> String? {
        // Look for: {"type":"thread.started","thread_id":"UUID"}
        for line in jsonLines.components(separatedBy: .newlines) {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String,
                  type == "thread.started",
                  let threadId = json["thread_id"] as? String else { continue }
            return threadId
        }
        return nil
    }

    func readDefaultModel() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let content = try? String(contentsOfFile: "\(home)/.codex/config.toml", encoding: .utf8) else { return nil }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("model") && !trimmed.hasPrefix("model_") && trimmed.contains("=") {
                return trimmed.split(separator: "=", maxSplits: 1).last?
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
        }
        return nil
    }

    func isAuthenticated() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return FileManager.default.fileExists(atPath: "\(home)/.codex/auth.json")
    }
}
