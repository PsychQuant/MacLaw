## Context

OpenAI Codex uses OAuth 2.0 Authorization Code flow with PKCE (Proof Key for Code Exchange). The auth server is `auth.openai.com`, callback on `localhost:1455`. This is the same flow used by Codex CLI and OpenClaw's `openai-codex` provider.

MacLaw's existing `LLMProvider` uses a simple Bearer token from `@keychain:` references. OAuth adds a second auth path that handles login, token storage, and automatic refresh.

## Goals / Non-Goals

**Goals:**
- `maclaw auth login` opens browser for OAuth, receives callback, stores tokens in Keychain
- Tokens auto-refresh before expiry
- Config supports `@oauth:openai-codex` credential type
- Works headless (display code for user to open manually)

**Non-Goals:**
- Other OAuth providers (Google, GitHub Copilot) — can add later using same framework
- Token sharing with Codex CLI or OpenClaw — each has its own token
- Web-based admin UI for token management

## Decisions

### Use NWListener for local callback server

Swift's `Network.framework` provides `NWListener` for lightweight TCP servers. We only need to handle one HTTP request (the OAuth callback), so a full HTTP framework is unnecessary. Parse the authorization code from the query string, respond with a success page, close the server.

Alternative: `HTTPServer` from Vapor/Hummingbird — rejected, too heavy for a single-request callback.

### Store OAuth tokens as structured JSON in Keychain

Store a single Keychain entry `oauth:openai-codex` containing JSON with `accessToken`, `refreshToken`, `expiresAt`. The OAuthManager reads and parses this on demand.

### Add @oauth: config prefix alongside @keychain:

The config parser resolves `@oauth:openai-codex` by:
1. Reading the OAuth credential from Keychain
2. Checking if the access token is expired
3. If expired, using the refresh token to get a new one (and saving it)
4. Returning the valid access token

This is transparent to LLMProvider — it just receives a Bearer token.

### PKCE flow parameters

```
Authorization endpoint: https://auth.openai.com/oauth/authorize
Token endpoint:         https://auth.openai.com/oauth/token
Callback:               http://localhost:1455/auth/callback
Scope:                  openid profile email
Code challenge method:  S256
```

## Risks / Trade-offs

- [Risk] OpenAI may change OAuth endpoints or client requirements → Mitigation: Keep endpoints configurable, not hardcoded
- [Risk] Port 1455 may be in use → Mitigation: Try port, if busy show error with manual paste fallback
- [Trade-off] No device code flow for headless environments — PKCE requires a browser redirect. For truly headless, user must use `@keychain:` with a manually obtained token.
