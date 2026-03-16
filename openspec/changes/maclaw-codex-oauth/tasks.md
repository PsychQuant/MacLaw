## 1. OAuth Core

- [x] 1.1 Implement `OAuthCredential` type and store OAuth tokens as structured JSON in Keychain — token storage in Keychain
- [x] 1.2 Implement PKCE helpers with PKCE flow parameters: generate code verifier, compute S256 challenge — OAuth PKCE login flow
- [x] 1.3 Implement `OAuthCallbackServer` using NWListener on port 1455 — use NWListener for local callback server, handle port 1455 in use fallback
- [x] 1.4 Implement `OAuthManager.login()` — full flow: generate PKCE, open browser, wait for callback, exchange code for tokens, save to Keychain
- [x] 1.5 Implement automatic token refresh — check expiry before API call, refresh if needed, update Keychain

## 2. Config Integration

- [x] 2.1 Add @oauth: config prefix alongside @keychain: — extend `ConfigLoader` to resolve config @oauth: reference for `@oauth:openai-codex`

## 3. CLI Commands

- [x] 3.1 Add `AuthCommand` with `maclaw auth login` and `maclaw auth status` subcommands — auth status CLI
- [x] 3.2 Register `AuthCommand` in MacLaw.swift entry point

## 4. Build and Test

- [x] 4.1 Build and verify `maclaw auth login` and `maclaw auth status` work locally
