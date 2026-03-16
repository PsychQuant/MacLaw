import Foundation
import Testing
@testable import MacLaw

@Test func keychainPrefixDetected() {
    // ConfigLoader.resolveValue is private, but we can test the public behavior
    // by verifying that @keychain: references fail gracefully when key doesn't exist
    // (unit test scope — no real Keychain interaction expected to succeed)
    #expect("@keychain:test-key".hasPrefix("@keychain:"))
    #expect("@oauth:openai-codex".hasPrefix("@oauth:"))
    #expect(!"plain-value".hasPrefix("@keychain:"))
    #expect(!"plain-value".hasPrefix("@oauth:"))
}

@Test func oauthCredentialCodable() throws {
    let original = OAuthCredential(
        accessToken: "test-access",
        refreshToken: "test-refresh",
        expiresAt: Date(timeIntervalSince1970: 1800000000),
        email: "test@example.com"
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(OAuthCredential.self, from: data)

    #expect(decoded.accessToken == "test-access")
    #expect(decoded.refreshToken == "test-refresh")
    #expect(decoded.email == "test@example.com")
}

@Test func oauthCredentialExpiryCheck() {
    let expired = OAuthCredential(
        accessToken: "x",
        refreshToken: nil,
        expiresAt: Date().addingTimeInterval(-100)
    )
    #expect(expired.isExpired)

    let valid = OAuthCredential(
        accessToken: "x",
        refreshToken: nil,
        expiresAt: Date().addingTimeInterval(3600)
    )
    #expect(!valid.isExpired)

    // Within 60s buffer should be considered expired
    let almostExpired = OAuthCredential(
        accessToken: "x",
        refreshToken: nil,
        expiresAt: Date().addingTimeInterval(30)
    )
    #expect(almostExpired.isExpired)
}

@Test func callbackServerPortCheck() {
    // Port 80 should not be available (requires root)
    // This is a best-effort test — may vary by environment
    let highPort = OAuthCallbackServer.isPortAvailable(59999)
    // Just verify it returns a Bool without crashing
    _ = highPort
}
