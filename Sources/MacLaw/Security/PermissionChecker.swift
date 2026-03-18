import Foundation

/// Checks macOS TCC (Transparency, Consent, and Control) permissions
/// and guides the user to grant them during setup.
enum PermissionChecker {

    struct Permission: Sendable {
        let service: String
        let label: String
        let settingsURL: String
        let isSystemLevel: Bool  // system-level TCC (requires System Settings UI)
    }

    /// Permissions that maclaw needs for full operation.
    static let required: [Permission] = [
        Permission(
            service: "kTCCServiceSystemPolicyAllFiles",
            label: "Full Disk Access",
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            isSystemLevel: true
        ),
        Permission(
            service: "kTCCServiceSystemPolicyDesktopFolder",
            label: "Desktop Folder",
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_DesktopFolder",
            isSystemLevel: false
        ),
        Permission(
            service: "kTCCServiceSystemPolicyDocumentsFolder",
            label: "Documents Folder",
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_DocumentsFolder",
            isSystemLevel: false
        ),
        Permission(
            service: "kTCCServiceSystemPolicyDownloadsFolder",
            label: "Downloads Folder",
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_DownloadsFolder",
            isSystemLevel: false
        ),
        Permission(
            service: "kTCCServicePhotos",
            label: "Photos",
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos",
            isSystemLevel: false
        ),
        Permission(
            service: "kTCCServiceAppleEvents",
            label: "Automation",
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            isSystemLevel: false
        ),
    ]

    /// Check which permissions are missing for the current binary.
    static func checkMissing() -> [Permission] {
        let binaryPath = ProcessInfo.processInfo.arguments[0]
        let resolvedPath = resolveBinaryPath(binaryPath)

        var missing: [Permission] = []
        for perm in required {
            if !isGranted(service: perm.service, client: resolvedPath, isSystemLevel: perm.isSystemLevel) {
                missing.append(perm)
            }
        }
        return missing
    }

    /// Run the permission check step in setup. Returns true if all granted.
    static func runSetupCheck() -> Bool {
        let missing = checkMissing()

        if missing.isEmpty {
            print("   ✓ All permissions granted")
            return true
        }

        print("   The following permissions are missing:\n")
        for (i, perm) in missing.enumerated() {
            print("   \(i + 1). \(perm.label)")
        }

        // Separate system-level (must use UI) from user-level
        let systemLevel = missing.filter(\.isSystemLevel)
        let userLevel = missing.filter { !$0.isSystemLevel }

        if !systemLevel.isEmpty {
            print("\n   These require manual approval in System Settings:")
            for perm in systemLevel {
                print("   • \(perm.label)")
            }
            print("\n   Opening System Settings...")
            // Open the first system-level permission page
            if let first = systemLevel.first {
                openSystemSettings(url: first.settingsURL)
            }
            print("   → Add '\(resolveBinaryPath(ProcessInfo.processInfo.arguments[0]))' and enable it.")
        }

        if !userLevel.isEmpty {
            print("\n   These will be requested when maclaw first accesses them:")
            for perm in userLevel {
                print("   • \(perm.label) — click Allow when prompted")
            }
        }

        print("\n   Press Enter after granting permissions to re-check...", terminator: "")
        _ = readLine()

        // Re-check
        let stillMissing = checkMissing()
        if stillMissing.isEmpty {
            print("   ✓ All permissions granted")
            return true
        }

        print("   ⚠ Still missing:")
        for perm in stillMissing {
            print("   • \(perm.label)")
        }
        print("   You can grant these later in System Settings > Privacy & Security.")
        return false
    }

    // MARK: - Private

    private static func isGranted(service: String, client: String, isSystemLevel: Bool) -> Bool {
        let dbPath: String
        if isSystemLevel {
            dbPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            dbPath = "\(home)/Library/Application Support/com.apple.TCC/TCC.db"
        }

        let query = "SELECT auth_value FROM access WHERE service='\(service)' AND client='\(client)' LIMIT 1;"
        let result = shell("sqlite3 '\(dbPath)' \"\(query)\" 2>/dev/null")

        // No entry = not yet requested (we'll treat as missing)
        guard !result.isEmpty else { return false }

        // auth_value: 0 = denied, 2 = allowed, 3 = limited, 5 = denied by user
        return result.trimmingCharacters(in: .whitespacesAndNewlines) == "2"
    }

    private static func resolveBinaryPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    private static func openSystemSettings(url: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
        process.waitUntilExit()
    }

    private static func shell(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
