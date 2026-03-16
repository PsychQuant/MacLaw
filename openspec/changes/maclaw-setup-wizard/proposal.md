## Why

MacLaw 部署到新 Mac 需要手動建目錄、存 Keychain secrets、寫 config、檢查 codex CLI。每次都要記住步驟，容易遺漏。一個互動式 `maclaw setup` 指令可以一步完成所有初始化。

## What Changes

- Add `maclaw setup` interactive command that walks through first-time configuration
- Validate prerequisites (codex CLI installed and authenticated)
- Store Telegram bot token in Keychain via secure prompt
- Generate `~/.maclaw/maclaw.json` with correct references
- Optionally install launchd daemon

## Capabilities

### New Capabilities

- `setup-wizard`: Interactive first-time setup command — validates prerequisites, stores secrets, generates config, optionally installs daemon.

### Modified Capabilities

(none)

## Impact

- Affected code: `Sources/MacLaw/Gateway/SetupCommand.swift` (new), `Sources/MacLaw/MacLaw.swift` (register command)
- No new dependencies
