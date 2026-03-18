# MacLaw

macOS-native AI agent runtime. Pure Swift, zero Node.js dependencies.

MacLaw turns any Mac into an AI-powered Telegram bot by bridging Telegram with LLM backend CLIs (Codex, Claude). It handles message routing, session persistence, access control, cron scheduling, and secrets management — all in a single static binary.

## Architecture

```
Telegram ←→ Gateway ←→ Backend CLI (codex / claude)
                │
           Cron Scheduler
```

MacLaw is a bridge, not an LLM wrapper. It delegates all AI work to backend CLIs and reads their configs directly — no model catalogs, no token management, no API keys.

## Features

- **Swappable backends** — Codex and Claude via their native CLIs
- **Persistent sessions** — one conversation per Telegram chat, survives restarts
- **Smart group chat** — responds to @mentions and replies, uses structured output to decide when to chime in
- **Access control** — DM/group policies with allowlists
- **Cron jobs** — scheduled prompts with Telegram delivery
- **Keychain secrets** — macOS Keychain for credential storage
- **launchd daemon** — install/uninstall as a macOS background service
- **Telegram commands** — `/model`, `/status`, `/permissions`, `/reset`, `/whoami`

## Requirements

- macOS 14+
- Swift 6.0+
- A backend CLI installed: [Codex](https://github.com/openai/codex) or [Claude Code](https://claude.ai/code)

## Quick Start

```bash
# Build
swift build -c release

# First-time setup (interactive — configures backend + Telegram + daemon)
.build/release/maclaw setup

# Run the gateway
.build/release/maclaw gateway run
```

## CLI Commands

```
maclaw setup                          # First-time setup wizard
maclaw gateway run|stop|restart|status

maclaw backend status                 # Show active backend, model, auth
maclaw backend set codex|claude       # Switch backend
maclaw backend login                  # Run backend's login flow
maclaw backend install <name>         # Install a backend CLI

maclaw secrets set|delete|list        # Keychain management
maclaw daemon install|uninstall|status
```

## Telegram Commands

| Command | Description |
|---------|-------------|
| `/help` | Show available commands |
| `/status` | Gateway status (PID, uptime, backend, model) |
| `/ping` | Health check |
| `/model` | Show current model and backend config |
| `/model set <name>` | Switch model at runtime |
| `/model reset` | Revert to backend default |
| `/permissions safe` | Whitelist-only tool access |
| `/permissions full` | Unrestricted tool access |
| `/reset` | Clear session, start fresh conversation |
| `/whoami` | Show your Telegram user info |

## Configuration

Config lives at `~/.maclaw/maclaw.json`:

```json
{
  "backend": "codex",
  "telegram": {
    "botToken": "...",
    "dmPolicy": "allowlist",
    "allowFrom": ["123456789"],
    "groupPolicy": "open",
    "botUsername": "MyBot_bot"
  },
  "allowedTools": ["Read", "Edit", "Write", "Bash", "Glob", "Grep"],
  "cron": {
    "jobs": [
      {
        "name": "daily-summary",
        "schedule": "every 24h",
        "prompt": "Summarize today's activity",
        "deliverTo": "123456789"
      }
    ]
  }
}
```

## Design Principles

- **Delegate to backend CLIs** — MacLaw never calls LLM APIs directly. Model discovery, auth, and context management are the backend's job.
- **Zero manual model config** — reads models from `~/.codex/config.toml` or `~/.claude/settings.json`.
- **Mac-native style** — flat CLI structure following macOS conventions (`launchctl`, `defaults`).
- **Session memory is the AI's job** — MacLaw maintains chat→session mappings; the backend handles compaction and context windows.

## Project Structure

```
Sources/MacLaw/
├── MacLaw.swift              # CLI entry point
├── Gateway/                  # Gateway runner, setup wizard
├── Agent/                    # Backend protocol + Codex/Claude adapters
├── Telegram/                 # Bot API, poller, sender, commands, access control
├── Cron/                     # Job scheduler + state persistence
├── Daemon/                   # launchd plist management
├── Security/                 # Keychain, config loader
└── Types/                    # Config types
```

## Deploy to a Remote Mac

```bash
swift build -c release
scp .build/release/maclaw <host>:~/maclaw-tmp
ssh <host> "sudo mv ~/maclaw-tmp /usr/local/bin/maclaw && sudo chmod +x /usr/local/bin/maclaw"
ssh <host> "maclaw daemon install && launchctl kickstart -k gui/501/ai.psychquant.maclaw"
```

## License

MIT
