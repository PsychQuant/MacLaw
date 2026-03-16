## Context

MacLaw is deployed by scp'ing the binary to a Mac and running setup manually. The setup wizard automates this into a single interactive flow. It must run from a local Terminal (not SSH) because Keychain access requires user session.

## Goals / Non-Goals

**Goals:**
- One command to go from fresh binary to running gateway
- Validate all prerequisites before starting
- Secure input for secrets (no echo)

**Non-Goals:**
- Remote/headless setup (Keychain requires local session)
- Config migration from OpenClaw

## Decisions

### Sequential interactive flow with validation at each step

The setup wizard runs steps in order. If any step fails, it stops and explains what to fix. Steps:

1. Check codex CLI: `which codex` + `codex auth status` (or equivalent)
2. Prompt for Telegram bot token → store in Keychain
3. Generate `~/.maclaw/maclaw.json`
4. Ask: install launchd daemon? → if yes, run `maclaw daemon install`
5. Ask: start gateway now? → if yes, run gateway

### Reuse existing components

The wizard calls `KeychainManager`, `ConfigLoader.ensureConfigDir()`, and `DaemonInstall` — no new infrastructure, just orchestration.

## Risks / Trade-offs

- [Risk] User runs via SSH → Keychain fails → Mitigation: detect SSH session and warn upfront
- [Trade-off] No idempotency — running setup twice overwrites config. Acceptable for v1; add `--force` flag if needed later.
