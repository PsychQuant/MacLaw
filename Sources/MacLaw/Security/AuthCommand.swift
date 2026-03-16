import ArgumentParser
import Foundation

struct AuthCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        abstract: "Manage OAuth authentication",
        subcommands: [AuthLogin.self, AuthStatus.self, AuthLogout.self]
    )
}

struct AuthLogin: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "login",
        abstract: "Authenticate with OpenAI via OAuth"
    )

    func run() async throws {
        let credential = try await OAuthManager.login()
        let email = credential.email ?? "unknown"
        let expiry = ISO8601DateFormatter().string(from: credential.expiresAt)
        print("Authenticated successfully!")
        print("  Email: \(email)")
        print("  Token expires: \(expiry)")
    }
}

struct AuthStatus: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show OAuth authentication status"
    )

    func run() throws {
        do {
            let credential = try OAuthStore.load(provider: "openai-codex")
            let expired = credential.isExpired
            let expiry = ISO8601DateFormatter().string(from: credential.expiresAt)
            let email = credential.email ?? "unknown"

            if expired {
                print(#"{"ok":true,"data":{"authenticated":true,"expired":true,"email":"\#(email)","expiresAt":"\#(expiry)"}}"#)
            } else {
                print(#"{"ok":true,"data":{"authenticated":true,"expired":false,"email":"\#(email)","expiresAt":"\#(expiry)"}}"#)
            }
        } catch {
            print(#"{"ok":true,"data":{"authenticated":false}}"#)
        }
    }
}

struct AuthLogout: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logout",
        abstract: "Remove stored OAuth credentials"
    )

    func run() throws {
        try OAuthStore.delete(provider: "openai-codex")
        print("OAuth credentials removed")
    }
}
