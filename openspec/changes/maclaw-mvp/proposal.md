## Why

OpenClaw (Node.js) on macOS suffers from fundamental platform mismatches: undici bypasses macOS network stack (IPv6/VPN), long-polling TCP dies on sleep/wake without recovery, and secrets are stored as plaintext JSON. These are not bugs — they're architectural limitations of running a Node.js runtime on macOS.

MacLaw is a macOS-native AI agent runtime in Swift that uses Apple's security and networking primitives to eliminate these issues by design. The MVP delivers a functional Telegram chatbot with cron scheduling that can run alongside OpenClaw on the same Mac Mini for A/B comparison.

## What Changes

- Implement Telegram Bot API client using `URLSession` with native IPv4/IPv6, sleep/wake recovery, and network path monitoring
- Implement LLM provider layer supporting OpenAI-compatible APIs (cloud + local Paw on Kyle)
- Implement cron scheduler with one-shot and recurring jobs, exponential backoff on failure
- Implement Keychain-based secrets management (bot tokens, API keys never touch disk as plaintext)
- Implement launchd integration for daemon lifecycle (auto-start, crash recovery)
- Wire everything into a `maclaw gateway run` CLI command

## Capabilities

### New Capabilities

- `telegram-transport`: Telegram Bot API client using URLSession — long-polling with automatic reconnection, send/receive messages, group and DM support.
- `llm-provider`: OpenAI-compatible LLM provider layer — model routing (cloud vs local), request/response handling, token counting.
- `cron-scheduler`: Job scheduler — one-shot (`at`) and recurring (`every`) jobs, exponential backoff, announce delivery via Telegram.
- `keychain-secrets`: Secrets management via macOS Keychain Services — store, retrieve, delete secrets with zero plaintext on disk.
- `launchd-daemon`: launchd plist generation and daemon lifecycle — install, uninstall, start, stop, status.

### Modified Capabilities

(none)

## Impact

- Affected code: `systems/MacLaw/Sources/MacLaw/` (all new code)
- New dependencies: `swift-telegram-sdk` (Telegram Bot API), `swift-argument-parser` (CLI)
- Build: `swift build` in `systems/MacLaw/`
- Deploy: `scp` binary to PsychQuantClaw, install launchd plist
- Coexistence: MacLaw runs on port 18790 alongside OpenClaw on 18789
