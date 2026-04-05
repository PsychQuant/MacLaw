import Foundation

/// A backend that MacLaw delegates LLM work to.
protocol Backend: Sendable {
    var name: String { get }
    var cliName: String { get }

    /// Run a prompt and return result (blocking — use spawn() for non-blocking).
    /// - isGroupChat: when true, backend uses structured output to decide whether to respond
    /// - sessionId: pass to resume an existing session
    func run(prompt: String, model: String?, sessionId: String?, isGroupChat: Bool, allowedTools: [String]?) async throws -> (response: String?, sessionId: String?, shouldRespond: Bool)

    /// Spawn a prompt as a detached process. Returns a BackendTask for monitoring.
    /// Output is written to a temp file. The caller is responsible for monitoring and cleanup.
    func spawn(prompt: String, model: String?, sessionId: String?, isGroupChat: Bool, allowedTools: [String]?, chatId: Int64) throws -> BackendTask

    /// Read the default model from the backend's own config.
    func readDefaultModel() -> String?

    /// Read full config status (model, effort, sandbox, etc.)
    func readConfigSummary() -> [String: String]

    /// Check if the backend is installed.
    func isInstalled() -> Bool

    /// Check if the user is authenticated.
    func isAuthenticated() -> Bool

    /// Install command (shell command to run).
    var installCommand: String { get }

    /// Install command hint (human-readable).
    var installHint: String { get }

    /// Login command hint.
    var loginHint: String { get }
}

extension Backend {
    func isInstalled() -> Bool {
        let result = shellRun("which \(cliName)")
        return result.exitCode == 0 && !result.stdout.isEmpty
    }

    func shellRun(_ command: String) -> ShellOutput {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? ""
        let extraPaths = ["/usr/local/bin", "/opt/homebrew/bin", "\(home)/Library/pnpm", "\(home)/.local/bin"]
        env["PATH"] = (extraPaths + [env["PATH"] ?? ""]).joined(separator: ":")
        process.environment = env
        process.arguments = ["-c", command]
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ShellOutput(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ShellOutput(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }
}

struct ShellOutput: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum BackendError: Error, LocalizedError {
    case launchFailed(String)
    case executionFailed(String)
    case notInstalled(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let msg): "Backend launch failed: \(msg)"
        case .executionFailed(let msg): "Backend error: \(msg)"
        case .notInstalled(let msg): "Backend not installed: \(msg)"
        }
    }
}
