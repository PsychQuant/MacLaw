import Foundation

enum ConfigLoader {
    private static let keychainPrefix = "@keychain:"
    private static let oauthPrefix = "@oauth:"

    static var configDir: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.maclaw"
    }

    static var configPath: String { "\(configDir)/maclaw.json" }

    static func load() throws -> MacLawConfig {
        let path = configPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigError.fileNotFound(path)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let config = try JSONDecoder().decode(MacLawConfig.self, from: data)
        return try resolveKeychainRefs(config)
    }

    static func ensureConfigDir() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDir) {
            try fm.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Keychain reference resolution

    private static func resolveKeychainRefs(_ config: MacLawConfig) throws -> MacLawConfig {
        var resolved = config

        if let tg = resolved.telegram {
            resolved.telegram?.botToken = try resolveValue(tg.botToken)
        }
        if let primary = resolved.llm?.primary, let key = primary.apiKey {
            resolved.llm?.primary?.apiKey = try resolveValue(key)
        }
        if let fallback = resolved.llm?.fallback, let key = fallback.apiKey {
            resolved.llm?.fallback?.apiKey = try resolveValue(key)
        }

        return resolved
    }

    private static func resolveValue(_ value: String) throws -> String {
        if value.hasPrefix(keychainPrefix) {
            let key = String(value.dropFirst(keychainPrefix.count))
            return try KeychainManager.get(key: key)
        }
        if value.hasPrefix(oauthPrefix) {
            // OAuth resolution needs async; use a synchronous bridge for config loading.
            // This blocks briefly but only runs once at startup.
            let provider = String(value.dropFirst(oauthPrefix.count))
            let credential = try OAuthStore.load(provider: provider)
            if credential.isExpired {
                // Can't do async refresh here; return expired token and let LLMProvider handle refresh
                // Or better: warn the user
                print("[config] Warning: OAuth token for '\(provider)' is expired. Run 'maclaw auth login' to refresh.")
            }
            return credential.accessToken
        }
        return value
    }
}

enum ConfigError: Error, LocalizedError {
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): "Config not found: \(path). Run 'maclaw init' to create one."
        }
    }
}
