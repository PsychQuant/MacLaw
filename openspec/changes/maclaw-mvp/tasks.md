## 1. Keychain Secrets

- [x] 1.1 Implement `KeychainManager` to store secrets in Keychain using Keychain Services for all secrets — store, retrieve, delete via Security.framework
- [x] 1.2 Implement `maclaw secrets set/delete/list` CLI commands (secrets management CLI)
- [x] 1.3 Implement JSON config file with Keychain references — `@keychain:` resolution in config parser

## 2. Telegram Transport

- [x] 2.1 Implement raw Telegram Bot API types (replaced swift-telegram-sdk with URLSession + Codable) dependency — use swift-telegram-sdk for Telegram Bot API
- [x] 2.2 Implement `TelegramPoller` — URLSession-based polling with NWPathMonitor recovery, long-polling with automatic reconnection on network change
- [x] 2.3 Implement `TelegramSender` — send messages with chunking for >4096 chars

## 3. LLM Provider

- [x] 3.1 Implement `LLMProvider` protocol and `OpenAIProvider` — chat completion via URLSession (OpenAI-compatible API client)
- [x] 3.2 Implement `ModelRouter` — primary/fallback routing with timeout and error handling (model routing)

## 4. Cron Scheduler

- [x] 4.1 Implement `CronJob` types and `CronState` persistence to `~/.maclaw/cron-state.json` (job state persistence)
- [x] 4.2 Implement timer-based cron scheduler — DispatchSourceTimer for recurring jobs, asyncAfter for one-shot jobs
- [x] 4.3 Implement backoff logic on job failure — 30s/1m/5m/15m/60m schedule

## 5. Gateway Wiring

- [x] 5.1 Wire gateway run: load config → resolve Keychain refs → start Telegram poller → start LLM provider → start cron scheduler
- [x] 5.2 Implement `maclaw gateway status` with JSON output

## 6. launchd Daemon

- [x] 6.1 Implement launchd plist for daemon lifecycle — launchd plist generation, daemon status, `maclaw daemon install/uninstall/status` commands

## 7. Build and Deploy

- [x] 7.1 Build release binary, test all commands locally
- [ ] 7.2 Deploy to PsychQuantClaw, install launchd plist, verify Telegram connectivity (blocked: need to set up Keychain secrets on Mac Mini first), install launchd plist, verify Telegram connectivity
