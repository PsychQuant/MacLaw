import Foundation

struct OAuthCredential: Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Date
    var email: String?

    var isExpired: Bool {
        Date().addingTimeInterval(60) >= expiresAt  // 60s buffer
    }
}

enum OAuthStore {
    private static let keychainKeyPrefix = "oauth:"

    static func save(provider: String, credential: OAuthCredential) throws {
        let data = try JSONEncoder().encode(credential)
        guard let json = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversion
        }
        try KeychainManager.set(key: "\(keychainKeyPrefix)\(provider)", value: json)
    }

    static func load(provider: String) throws -> OAuthCredential {
        let json = try KeychainManager.get(key: "\(keychainKeyPrefix)\(provider)")
        guard let data = json.data(using: .utf8) else {
            throw KeychainError.dataConversion
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OAuthCredential.self, from: data)
    }

    static func delete(provider: String) throws {
        try KeychainManager.delete(key: "\(keychainKeyPrefix)\(provider)")
    }

    static func exists(provider: String) -> Bool {
        (try? load(provider: provider)) != nil
    }
}
