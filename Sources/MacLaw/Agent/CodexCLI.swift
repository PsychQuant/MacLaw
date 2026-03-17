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

    func run(prompt: String, model: String? = nil) async throws -> String {
        let outputFile = NSTemporaryDirectory() + "maclaw-codex-\(UUID().uuidString).txt"
        defer { try? FileManager.default.removeItem(atPath: outputFile) }

        let fullPrompt = "\(systemPrompt)\n\nUser message: \(prompt)"

        let process = Process()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var args = [
            "codex", "exec",
            fullPrompt,
            "--sandbox", "read-only",
            "--skip-git-repo-check",
            "--ephemeral",
            "-o", outputFile,
        ]
        if let model {
            args += ["-m", model]
        }
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = stderrPipe

        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? ""
        let extraPaths = ["/usr/local/bin", "/opt/homebrew/bin", "\(home)/Library/pnpm", "\(home)/.local/bin"]
        env["PATH"] = (extraPaths + [env["PATH"] ?? ""]).joined(separator: ":")
        process.environment = env

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let output = (try? String(contentsOfFile: outputFile, encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !output.isEmpty {
                    continuation.resume(returning: output)
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
