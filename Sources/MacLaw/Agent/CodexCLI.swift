import Foundation

struct CodexBackend: Backend {
    let name = "codex"
    let cliName = "codex"
    let installCommand = "brew install codex"
    let installHint = "brew install codex"
    let loginHint = "codex --login"

    func run(prompt: String, model: String? = nil, sessionId: String? = nil, isGroupChat: Bool = false) async throws -> (response: String?, sessionId: String?, shouldRespond: Bool) {
        let outputFile = NSTemporaryDirectory() + "maclaw-codex-\(UUID().uuidString).txt"
        defer { try? FileManager.default.removeItem(atPath: outputFile) }

        // For group chat, write a schema file for --output-schema
        var schemaFile: String?
        if isGroupChat {
            let schema = """
            {"type":"object","properties":{"shouldRespond":{"type":"boolean"},"response":{"type":"string"}},"required":["shouldRespond"]}
            """
            let path = NSTemporaryDirectory() + "maclaw-schema-\(UUID().uuidString).json"
            try schema.write(toFile: path, atomically: true, encoding: .utf8)
            schemaFile = path
        }
        defer { if let sf = schemaFile { try? FileManager.default.removeItem(atPath: sf) } }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")

        var args: [String]
        if let sid = sessionId {
            args = ["codex", "exec", "resume", sid, prompt,
                    "-o", outputFile, "--skip-git-repo-check", "--full-auto", "--json"]
        } else {
            args = ["codex", "exec", prompt,
                    "--full-auto", "--skip-git-repo-check",
                    "-o", outputFile, "--json"]
        }
        if let model {
            args += ["-m", model]
        }
        if let sf = schemaFile {
            args += ["--output-schema", sf]
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

                let threadId = Self.extractThreadId(from: stdout)

                if isGroupChat {
                    // Parse structured output from the output file
                    let parsed = Self.parseGroupOutput(output)
                    continuation.resume(returning: (parsed.response, threadId, parsed.shouldRespond))
                } else if !output.isEmpty {
                    continuation.resume(returning: (output, threadId, true))
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

    private static func parseGroupOutput(_ output: String) -> (response: String?, shouldRespond: Bool) {
        guard let data = output.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Not JSON — treat as plain text response
            return (output.isEmpty ? nil : output, true)
        }
        let shouldRespond = json["shouldRespond"] as? Bool ?? true
        let response = json["response"] as? String
        return (response, shouldRespond)
    }

    private static func extractThreadId(from jsonLines: String) -> String? {
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
        readConfigSummary()["model"]
    }

    func readConfigSummary() -> [String: String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let content = try? String(contentsOfFile: "\(home)/.codex/config.toml", encoding: .utf8) else { return [:] }
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { break }
            guard trimmed.contains("=") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            result[key] = value
        }
        return result
    }

    func isAuthenticated() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return FileManager.default.fileExists(atPath: "\(home)/.codex/auth.json")
    }
}
