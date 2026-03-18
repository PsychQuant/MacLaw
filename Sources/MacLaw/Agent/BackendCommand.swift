import ArgumentParser
import Foundation

struct BackendCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backend",
        abstract: "Manage the AI backend (codex or claude)",
        subcommands: [BackendStatus.self, BackendSet.self, BackendInstall.self, BackendLogin.self]
    )
}

struct BackendStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show active backend, model, and auth status"
    )

    func run() throws {
        let config = try? ConfigLoader.load()
        let backendName = config?.backend ?? "codex"
        let backend = BackendRegistry.resolve(name: backendName)
        let installed = backend.isInstalled()
        let authenticated = installed ? backend.isAuthenticated() : false
        let model = installed ? (backend.readDefaultModel() ?? "default") : "n/a"

        print("Backend:  \(backend.name)")
        print("CLI:      \(backend.cliName) \(installed ? "✓" : "✗ (not installed: \(backend.installHint))")")
        print("Auth:     \(authenticated ? "✓ authenticated" : "✗ (run: \(backend.loginHint))")")
        print("Model:    \(model)")
    }
}

struct BackendSet: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Switch backend (codex or claude)"
    )

    @Argument(help: "Backend name: codex or claude")
    var name: String

    func run() throws {
        guard BackendRegistry.allNames.contains(name) else {
            print("Unknown backend: \(name)")
            print("Available: \(BackendRegistry.allNames.joined(separator: ", "))")
            throw ExitCode.failure
        }

        // Update config
        let configPath = ConfigLoader.configPath
        var config: MacLawConfig
        if let existing = try? ConfigLoader.load() {
            config = existing
        } else {
            config = MacLawConfig()
        }

        // We need to write the raw JSON with backend field
        // Since MacLawConfig might not have resolved @keychain refs, read raw JSON
        let path = configPath
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = parsed
        }
        json["backend"] = name
        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: path))

        let backend = BackendRegistry.resolve(name: name)
        print("Backend set to: \(name)")
        if !backend.isInstalled() {
            print("⚠ \(backend.cliName) not installed. Run: maclaw backend install \(name)")
        }
    }
}

struct BackendInstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install a backend CLI (codex or claude)"
    )

    @Argument(help: "Backend name: codex or claude")
    var name: String

    func run() throws {
        guard let backend = (BackendRegistry.allNames.contains(name) ? BackendRegistry.resolve(name: name) : nil) else {
            print("Unknown backend: \(name)")
            print("Available: \(BackendRegistry.allNames.joined(separator: ", "))")
            throw ExitCode.failure
        }

        if backend.isInstalled() {
            print("\(backend.cliName) is already installed")
            return
        }

        print("Installing \(backend.cliName)...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", backend.installCommand]
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? ""
        env["PATH"] = ["/usr/local/bin", "/opt/homebrew/bin", "\(home)/.local/bin", env["PATH"] ?? ""].joined(separator: ":")
        process.environment = env

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("✓ \(backend.cliName) installed")
        } else {
            print("Install failed with status \(process.terminationStatus)")
            throw ExitCode.failure
        }
    }
}

struct BackendLogin: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Run the backend's login flow"
    )

    func run() throws {
        let config = try? ConfigLoader.load()
        let backendName = config?.backend ?? "codex"
        let backend = BackendRegistry.resolve(name: backendName)

        guard backend.isInstalled() else {
            print("\(backend.cliName) not installed. Run: \(backend.installHint)")
            throw ExitCode.failure
        }

        print("Running \(backend.cliName) login...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = backend.loginHint.split(separator: " ").map(String.init)
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        var env = ProcessInfo.processInfo.environment
        let home = env["HOME"] ?? ""
        env["PATH"] = ["/usr/local/bin", "/opt/homebrew/bin", "\(home)/Library/pnpm", env["PATH"] ?? ""].joined(separator: ":")
        process.environment = env

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            print("✓ Login complete")
        } else {
            print("Login exited with status \(process.terminationStatus)")
        }
    }
}
