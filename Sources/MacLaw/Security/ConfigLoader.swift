import Foundation

enum ConfigLoader {
    private static let keychainPrefix = "@keychain:"

    static var configDir: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.maclaw"
    }

    static var configPath: String { "\(configDir)/maclaw.json" }

    /// Load config without resolving secrets. Safe for CLI commands that only read config structure.
    static func load() throws -> MacLawConfig {
        let path = configPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigError.fileNotFound(path)
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(MacLawConfig.self, from: data)
    }

    /// Load config with all @keychain: refs resolved. Use only when actual secret values are needed (e.g., gateway startup).
    static func loadResolved() throws -> MacLawConfig {
        let config = try load()
        return try resolveRefs(config)
    }

    static func ensureConfigDir() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: configDir) {
            try fm.createDirectory(atPath: configDir, withIntermediateDirectories: true)
        }
    }

    private static func resolveRefs(_ config: MacLawConfig) throws -> MacLawConfig {
        var resolved = config
        if let tg = resolved.telegram {
            resolved.telegram?.botToken = try resolveValue(tg.botToken)
        }
        return resolved
    }

    private static func resolveValue(_ value: String) throws -> String {
        if value.hasPrefix(keychainPrefix) {
            let key = String(value.dropFirst(keychainPrefix.count))
            return try KeychainManager.get(key: key)
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
