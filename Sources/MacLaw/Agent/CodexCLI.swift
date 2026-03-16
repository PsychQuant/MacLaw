import Foundation

/// Calls `codex exec` to process prompts non-interactively.
enum CodexCLI {
    private static let systemPrompt = """
        You are a helpful AI assistant running as a Telegram chatbot called MacLaw. \
        Respond conversationally in the user's language. \
        Do NOT read files, run commands, or act as a code agent. \
        Just answer the user's question directly and concisely.
        """

    static func run(prompt: String) async throws -> String {
        let outputFile = NSTemporaryDirectory() + "maclaw-codex-\(UUID().uuidString).txt"
        defer { try? FileManager.default.removeItem(atPath: outputFile) }

        let fullPrompt = "\(systemPrompt)\n\nUser message: \(prompt)"

        let process = Process()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "codex", "exec",
            fullPrompt,
            "--sandbox", "read-only",
            "--skip-git-repo-check",
            "--ephemeral",
            "-o", outputFile,
        ]
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
