## Context

MacLaw is a new Swift CLI (`maclaw`) in the `systems/MacLaw/` submodule. The existing scaffold has `Package.swift`, entry point, and a `gateway` command stub. The target machine is PsychQuantClaw (Mac Mini M4, macOS 14+, Apple Silicon), running alongside OpenClaw on a different port.

Key Swift ecosystem pieces:
- `swift-telegram-sdk` — full Telegram Bot API wrapper, works with URLSession
- `URLSession` — handles IPv4/IPv6, sleep/wake reconnection, VPN/proxy natively
- `Security.framework` — Keychain Services for secret storage
- `Network.framework` — `NWPathMonitor` for connectivity change detection
- `Foundation.Timer` / `DispatchSourceTimer` — cron scheduling

## Goals / Non-Goals

**Goals:**
- Telegram chatbot that never loses messages due to network issues
- LLM integration with OpenAI API + local Paw (OpenAI-compatible)
- Cron jobs (one-shot + recurring) with Telegram delivery
- Secrets in Keychain, zero plaintext
- launchd daemon with crash recovery

**Non-Goals:**
- Tool execution / shell exec (v2 — requires XPC sandbox design)
- Multi-agent (v2)
- Other channels: Discord, Slack, Signal (v2)
- Skill/plugin system (v2)
- Session history compaction (v2)
- GUI / menubar app (v2)

## Decisions

### Use swift-telegram-sdk for Telegram Bot API

Provides full Bot API coverage (sendMessage, getUpdates, sendChatAction, etc.) and works with any Swift HTTP client including URLSession. We wrap it with our own polling loop using `NWPathMonitor` to detect network changes and trigger reconnection.

Alternative: Raw URLSession + manual JSON — rejected, too much boilerplate for full Bot API coverage.

### URLSession-based polling with NWPathMonitor recovery

The core advantage over OpenClaw: URLSession handles IPv4/IPv6 transition, sleep/wake TCP recovery, and VPN routing natively. `NWPathMonitor` notifies us when network path changes (e.g., wake from sleep), and we immediately restart the polling loop — no 90s watchdog timeout needed.

```
NWPathMonitor ──► path changed ──► cancel current getUpdates
                                 ──► reconnect immediately
```

Alternative: Webhook mode — deferred to v2 (requires public URL setup).

### Keychain Services for all secrets

Bot token and API keys stored via `SecItemAdd`/`SecItemCopyMatching`. The `maclaw secrets` command manages them. Config file (`maclaw.json`) uses key references, never plaintext values.

```swift
// Store
SecItemAdd([kSecClass: kSecClassGenericPassword,
            kSecAttrService: "maclaw",
            kSecAttrAccount: "telegram-bot-token",
            kSecValueData: tokenData] as CFDictionary, nil)

// Retrieve (never exposed as String in logs)
SecItemCopyMatching([...] as CFDictionary, &result)
```

Alternative: Encrypted file (like OpenClaw's secrets.json) — rejected, Keychain is more secure and integrates with macOS access control.

### JSON config file with Keychain references

`~/.maclaw/maclaw.json` stores non-secret configuration. Secrets are referenced by Keychain key name, not stored inline.

```json
{
  "telegram": { "botToken": "@keychain:telegram-bot-token" },
  "llm": {
    "primary": { "baseUrl": "https://api.openai.com/v1", "apiKey": "@keychain:openai-api-key", "model": "gpt-5.4" },
    "fallback": { "baseUrl": "http://10.83.150.206:8081/v1", "model": "mlx-community/Qwen3.5-122B-A10B-6bit" }
  },
  "cron": { "jobs": [] }
}
```

### Timer-based cron scheduler

Use `DispatchSourceTimer` for recurring jobs and `DispatchQueue.asyncAfter` for one-shot. Each job stores: id, name, schedule, prompt, model override, delivery target. State persisted to `~/.maclaw/cron-state.json`.

Backoff on failure: 30s → 1m → 5m → 15m → 60m (matching OpenClaw's schedule).

### launchd plist for daemon lifecycle

Generate and install a LaunchDaemon plist at `~/Library/LaunchAgents/ai.psychquant.maclaw.plist`. Supports `maclaw daemon install`, `maclaw daemon uninstall`, `maclaw daemon status`.

## Risks / Trade-offs

- [Risk] `swift-telegram-sdk` may have bugs or missing features → Mitigation: It covers full Bot API; can fall back to raw URLSession for specific endpoints
- [Risk] Keychain access requires user approval on first use → Mitigation: Document the one-time Keychain prompt in setup guide
- [Trade-off] No session persistence in MVP — conversation history is in-memory only, lost on restart. Acceptable for MVP; file-backed sessions in v2.
- [Trade-off] No streaming preview in Telegram — messages sent only after LLM completes. Simpler and avoids the editMessage rate limiting issues OpenClaw has.
