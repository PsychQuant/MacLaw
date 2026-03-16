## Why

MacLaw MVP 目前只支援 API key 認證（Bearer token）。但 OpenAI Codex 使用 OAuth PKCE flow 認證，這是 Codex CLI 和 OpenClaw 都使用的方式。沒有 OAuth 支援，MacLaw 無法連接 OpenAI 的 OAuth-only endpoints，也無法重用使用者在 Codex CLI 已授權的帳號。

## What Changes

- Implement OAuth PKCE authorization code flow against `auth.openai.com`
- Run a local HTTP callback server on `localhost:1455` to receive the auth code
- Store OAuth tokens (access, refresh, expiry) in macOS Keychain
- Auto-refresh expired tokens before API calls
- Add `maclaw auth login` / `maclaw auth status` CLI commands
- Update `LLMProvider` to support `@oauth:openai-codex` credential type alongside `@keychain:`

## Capabilities

### New Capabilities

- `codex-oauth`: OAuth PKCE flow for OpenAI Codex authentication — login via browser, callback server, token storage in Keychain, automatic refresh.

### Modified Capabilities

(none)

## Impact

- Affected code: `systems/MacLaw/Sources/MacLaw/Security/` (new OAuthManager), `systems/MacLaw/Sources/MacLaw/Agent/LLMProvider.swift` (auth mode support), new `AuthCommand.swift`
- No new Swift package dependencies — uses URLSession for HTTP, `Network.framework` for local server
- Config format extension: `"apiKey": "@oauth:openai-codex"` triggers OAuth token resolution
