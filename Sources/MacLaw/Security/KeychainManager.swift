import Foundation

enum KeychainError: Error, LocalizedError {
    case notFound
    case commandFailed(String)
    case dataConversion

    var errorDescription: String? {
        switch self {
        case .notFound: "Secret not found in Keychain"
        case .commandFailed(let msg): "Keychain error: \(msg)"
        case .dataConversion: "Failed to convert Keychain data"
        }
    }
}

/// Keychain access via `security` CLI — avoids authorization prompts on unsigned binaries.
enum KeychainManager {
    private static let serviceName = "maclaw"

    static func set(key: String, value: String) throws {
        // -U = update if exists, -s = service, -a = account, -w = password
        let result = shell("security add-generic-password -s \(serviceName) -a \(key) -w \(shellEscape(value)) -U")
        guard result.exitCode == 0 else {
            throw KeychainError.commandFailed(result.stderr.isEmpty ? "exit \(result.exitCode)" : result.stderr)
        }
    }

    static func get(key: String) throws -> String {
        // -w = print password only
        let result = shell("security find-generic-password -s \(serviceName) -a \(key) -w")
        guard result.exitCode == 0 else {
            if result.stderr.contains("could not be found") || result.exitCode == 44 {
                throw KeychainError.notFound
            }
            throw KeychainError.commandFailed(result.stderr.isEmpty ? "exit \(result.exitCode)" : result.stderr)
        }
        let value = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw KeychainError.notFound }
        return value
    }

    static func delete(key: String) throws {
        let result = shell("security delete-generic-password -s \(serviceName) -a \(key)")
        // Exit 44 = not found, which is fine for delete
        guard result.exitCode == 0 || result.exitCode == 44 else {
            throw KeychainError.commandFailed(result.stderr)
        }
    }

    static func listKeys() throws -> [String] {
        // Dump keychain and grep for our service name
        let result = shell("security dump-keychain | grep -A4 'svce.*=.*\"\(serviceName)\"' | grep 'acct' | sed 's/.*=\"\\(.*\\)\"/\\1/'")
        guard result.exitCode == 0 else { return [] }
        return result.stdout
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    // MARK: - Shell helpers

    private struct ShellResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    private static func shell(_ command: String) -> ShellResult {
        let process = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ShellResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ShellResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }

    private static func shellEscape(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
