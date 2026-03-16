## ADDED Requirements

### Requirement: OAuth PKCE login flow

The system SHALL implement OAuth 2.0 Authorization Code flow with PKCE against `auth.openai.com`. The system SHALL generate a random code verifier, compute a S256 code challenge, open the authorization URL in the user's default browser, and run a local HTTP listener on port 1455 to receive the callback. Upon receiving the authorization code, the system SHALL exchange it for access and refresh tokens via the token endpoint.

#### Scenario: Successful browser login

- **WHEN** the user runs `maclaw auth login`
- **THEN** the system opens the browser to the authorization URL, receives the callback, exchanges the code for tokens, stores them in Keychain, and prints a success message

#### Scenario: Port 1455 in use

- **WHEN** port 1455 is already bound by another process
- **THEN** the system SHALL print the authorization URL and prompt the user to paste the redirect URL manually after completing login in the browser

#### Scenario: User cancels login

- **WHEN** the user does not complete the browser login within 120 seconds
- **THEN** the system SHALL time out, stop the callback server, and print an error message

### Requirement: Token storage in Keychain

The system SHALL store OAuth credentials (access token, refresh token, expiry timestamp) as a single JSON-encoded Keychain entry under the key `oauth:openai-codex`. The system SHALL NOT write tokens to any file on disk.

#### Scenario: Tokens stored after login

- **WHEN** OAuth login completes successfully
- **THEN** the credentials are stored in Keychain and retrievable via `OAuthManager`

### Requirement: Automatic token refresh

The system SHALL check token expiry before each API call. If the access token is expired or will expire within 60 seconds, the system SHALL use the refresh token to obtain a new access token from the token endpoint and update the Keychain entry.

#### Scenario: Expired token auto-refreshes

- **WHEN** an API call is made and the access token has expired
- **THEN** the system uses the refresh token to get a new access token, updates Keychain, and proceeds with the API call using the new token

#### Scenario: Refresh token also expired

- **WHEN** the refresh token is rejected by the server
- **THEN** the system prints an error message instructing the user to run `maclaw auth login` again

### Requirement: Config @oauth: reference

The system SHALL support `@oauth:openai-codex` syntax in `maclaw.json` as an `apiKey` value. The config loader SHALL resolve this by reading the OAuth credential from Keychain and returning a valid access token (refreshing if needed).

#### Scenario: Config uses OAuth reference

- **WHEN** the config contains `"apiKey": "@oauth:openai-codex"`
- **THEN** the config loader resolves it to a valid access token at runtime

### Requirement: Auth status CLI

The system SHALL provide `maclaw auth status` that shows whether OAuth credentials exist, whether the token is valid or expired, and the associated email (if available from the ID token).

#### Scenario: Authenticated user

- **WHEN** valid OAuth credentials exist in Keychain
- **THEN** `maclaw auth status` outputs JSON with `authenticated: true`, `email`, and `expiresAt`

#### Scenario: No credentials

- **WHEN** no OAuth credentials exist
- **THEN** `maclaw auth status` outputs JSON with `authenticated: false`
