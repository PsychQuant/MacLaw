import Foundation

/// Calls `codex -p` to process prompts. Delegates all LLM logic to the Codex CLI.
enum CodexCLI {
    /// Run a prompt through Codex CLI and return the response text.
    static func run(prompt: String, outputFormat: String = "text", maxTurns: Int = 1) async throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["codex", "-p", prompt, "--output-format", outputFormat, "--max-turns", String(maxTurns)]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Inherit PATH so codex is found
        var env = ProcessInfo.processInfo.environment
        let extraPaths = ["/usr/local/bin", "/opt/homebrew/bin", "\(env["HOME"] ?? "")/Library/pnpm", "\(env["HOME"] ?? "")/.local/bin"]
        env["PATH"] = (extraPaths + [env["PATH"] ?? ""]).joined(separator: ":")
        process.environment = env

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { proc in
                let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if proc.terminationStatus == 0, !stdout.isEmpty {
                    continuation.resume(returning: stdout)
                } else {
                    let error = stderr.isEmpty ? "codex exited with status \(proc.terminationStatus)" : stderr
                    continuation.resume(throwing: CodexError.executionFailed(error))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: CodexError.launchFailed(error.localizedDescription))
            }
        }
    }
}

enum CodexError: Error, LocalizedError {
    case launchFailed(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): "Failed to launch codex: \(msg)"
        case .executionFailed(let msg): "Codex error: \(msg)"
        }
    }
}
