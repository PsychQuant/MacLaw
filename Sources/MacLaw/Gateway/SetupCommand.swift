import ArgumentParser
import Foundation

struct SetupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Interactive first-time setup"
    )

    func run() throws {
        print("=== MacLaw Setup ===\n")

        // Step 0: SSH warning
        if ProcessInfo.processInfo.environment["SSH_CONNECTION"] != nil
            || ProcessInfo.processInfo.environment["SSH_TTY"] != nil {
            print("⚠️  You appear to be running via SSH.")
            print("   Keychain access may fail. Run 'maclaw setup' from a local Terminal instead.\n")
            print("Continue anyway? (y/n): ", terminator: "")
            guard readLine()?.lowercased() == "y" else {
                print("Aborted.")
                throw ExitCode.failure
            }
        }

        // Step 1: Check codex CLI
        print("1. Checking codex CLI...")
        let codexCheck = shell("which codex")
        if codexCheck.isEmpty {
            print("   ✗ codex not found. Install it:")
            print("     npm i -g @openai/codex")
            print("     codex --login")
            throw ExitCode.failure
        }
        print("   ✓ codex found at \(codexCheck)")

        // Check codex auth (best effort)
        let codexAuth = shell("ls ~/.codex/auth.json 2>/dev/null")
        if codexAuth.isEmpty {
            print("   ✗ codex not authenticated. Run:")
            print("     codex --login")
            throw ExitCode.failure
        }
        print("   ✓ codex authenticated")

        // Step 2: Telegram bot token
        print("\n2. Telegram bot token")
        let existingToken = try? KeychainManager.get(key: "telegram-bot-token")
        if existingToken != nil {
            print("   Token already stored in Keychain.")
            print("   Overwrite? (y/n): ", terminator: "")
            if readLine()?.lowercased() != "y" {
                print("   Keeping existing token.")
            } else {
                try promptAndStoreToken()
            }
        } else {
            try promptAndStoreToken()
        }

        // Step 3: Generate config
        print("\n3. Generating config...")
        try ConfigLoader.ensureConfigDir()
        let configPath = ConfigLoader.configPath
        let config = """
        {
          "telegram": {
            "botToken": "@keychain:telegram-bot-token"
          }
        }
        """
        try config.write(toFile: configPath, atomically: true, encoding: .utf8)
        print("   ✓ Config written to \(configPath)")

        // Step 4: launchd daemon
        print("\n4. Install launchd daemon?")
        print("   This will auto-start MacLaw on login and restart on crash.")
        print("   Install? (y/n): ", terminator: "")
        if readLine()?.lowercased() == "y" {
            // Reuse DaemonInstall logic
            try DaemonInstall().run()
        } else {
            print("   Skipped. Start manually with: maclaw gateway run")
        }

        print("\n=== Setup Complete ===")
        print("Send a message to your bot on Telegram to test!")
    }

    private func promptAndStoreToken() throws {
        print("   Enter bot token (from @BotFather): ", terminator: "")
        // Use regular readLine since we need to see input in setup context
        guard let token = readLine(), !token.isEmpty else {
            print("   ✗ No token provided")
            throw ExitCode.failure
        }
        try KeychainManager.set(key: "telegram-bot-token", value: token)
        print("   ✓ Token stored in Keychain")
    }

    private func shell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH && \(command)"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
