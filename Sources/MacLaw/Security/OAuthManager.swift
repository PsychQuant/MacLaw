import Foundation

enum OAuthManager {
    // MARK: - Configuration

    private static let authEndpoint = "https://auth.openai.com/oauth/authorize"
    private static let tokenEndpoint = "https://auth.openai.com/oauth/token"
    private static let callbackURL = "http://localhost:1455/auth/callback"
    private static let callbackPort: UInt16 = 1455
    private static let scope = "openid profile email"
    // OpenAI Codex CLI uses a well-known public client ID
    private static let clientId = "app_codex"

    // MARK: - Login

    static func login() async throws -> OAuthCredential {
        let verifier = PKCEHelper.generateCodeVerifier()
        let challenge = PKCEHelper.computeCodeChallenge(verifier: verifier)

        let authURL = buildAuthURL(challenge: challenge)

        let code: String

        if OAuthCallbackServer.isPortAvailable(callbackPort) {
            // Normal flow: start server, open browser
            let server = OAuthCallbackServer(port: callbackPort)
            print("Opening browser for OpenAI authentication...")
            print("Callback listening on localhost:\(callbackPort)")
            openBrowser(url: authURL)

            code = try await server.waitForCode(timeoutSeconds: 120)
        } else {
            // Fallback: manual paste
            print("Port \(callbackPort) is in use. Manual login required.")
            print()
            print("Open this URL in your browser:")
            print(authURL)
            print()
            print("After login, paste the full redirect URL here:")
            guard let input = readLine(), let url = URLComponents(string: input),
                  let c = url.queryItems?.first(where: { $0.name == "code" })?.value else {
                throw OAuthError.noCodeInCallback
            }
            code = c
        }

        // Exchange code for tokens
        let credential = try await exchangeCode(code, verifier: verifier)

        // Store in Keychain
        try OAuthStore.save(provider: "openai-codex", credential: credential)
        return credential
    }

    // MARK: - Token refresh

    static func getValidToken(provider: String = "openai-codex") async throws -> String {
        var credential = try OAuthStore.load(provider: provider)

        if credential.isExpired {
            guard let refreshToken = credential.refreshToken else {
                throw OAuthError.notAuthenticated
            }
            credential = try await refreshAccessToken(refreshToken: refreshToken)
            try OAuthStore.save(provider: provider, credential: credential)
        }

        return credential.accessToken
    }

    // MARK: - Private helpers

    private static func buildAuthURL(challenge: String) -> String {
        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: callbackURL),
            URLQueryItem(name: "scope", value: scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]
        return components.url!.absoluteString
    }

    private static func exchangeCode(_ code: String, verifier: String) async throws -> OAuthCredential {
        let url = URL(string: tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=authorization_code",
            "code=\(code)",
            "redirect_uri=\(callbackURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? callbackURL)",
            "client_id=\(clientId)",
            "code_verifier=\(verifier)",
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw OAuthError.tokenExchangeFailed(errorBody)
        }

        return try parseTokenResponse(data)
    }

    private static func refreshAccessToken(refreshToken: String) async throws -> OAuthCredential {
        let url = URL(string: tokenEndpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(clientId)",
        ].joined(separator: "&")

        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw OAuthError.refreshFailed(errorBody)
        }

        return try parseTokenResponse(data)
    }

    private static func parseTokenResponse(_ data: Data) throws -> OAuthCredential {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw OAuthError.tokenExchangeFailed("invalid response format")
        }

        let refreshToken = json["refresh_token"] as? String
        let expiresIn = json["expires_in"] as? Int ?? 3600
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

        // Try to extract email from id_token (JWT payload, unverified)
        var email: String?
        if let idToken = json["id_token"] as? String {
            email = extractEmailFromJWT(idToken)
        }

        return OAuthCredential(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt,
            email: email
        )
    }

    private static func extractEmailFromJWT(_ jwt: String) -> String? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        // Add base64 padding
        while payload.count % 4 != 0 {
            payload += "="
        }
        payload = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["email"] as? String
    }

    private static func openBrowser(url: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url]
        try? process.run()
    }
}
