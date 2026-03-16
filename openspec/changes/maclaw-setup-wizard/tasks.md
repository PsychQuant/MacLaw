## 1. Setup Command

- [x] 1.1 Add `SetupCommand` with sequential interactive flow with validation at each step — prerequisite validation (codex CLI, SSH detection)
- [x] 1.2 Implement Telegram bot token setup — secure prompt, store in Keychain, handle token already exists
- [x] 1.3 Implement config generation — write `~/.maclaw/maclaw.json` with `@keychain:` reference
- [x] 1.4 Implement optional daemon installation — ask user, call existing DaemonInstall logic, reuse existing components

## 2. Integration

- [x] 2.1 Register `SetupCommand` in MacLaw.swift
- [x] 2.2 Build and verify `maclaw setup` runs locally
