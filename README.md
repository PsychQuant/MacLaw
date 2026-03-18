# MacLaw

macOS-native AI agent runtime. Pure Swift, zero Node.js dependencies.

## Requirements

- macOS 14+
- Swift 6.0+
- A backend CLI: [Codex](https://github.com/openai/codex) or [Claude Code](https://claude.ai/code)

## Quick Start

```bash
swift build -c release
.build/release/maclaw setup
.build/release/maclaw gateway run
```

## CLI

```
maclaw setup                          # First-time setup
maclaw gateway run|stop|restart|status

maclaw backend status                 # Active backend, model, auth
maclaw backend set codex|claude       # Switch backend
maclaw backend login                  # Backend login flow
maclaw backend install <name>         # Install a backend CLI

maclaw secrets set|delete|list        # Keychain management
maclaw daemon install|uninstall|status
```

## Telegram Commands

| Command | Description |
|---------|-------------|
| `/help` | Available commands |
| `/status` | Gateway status |
| `/ping` | Health check |
| `/model` | Current model info |
| `/model set <name>` | Switch model |
| `/model reset` | Revert to default |
| `/permissions safe\|full` | Toggle tool access |
| `/reset` | Clear session |
| `/whoami` | Telegram user info |

## License

MIT
