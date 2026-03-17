<!-- SPECTRA:START v1.0.1 -->
# Spectra Instructions

This project uses Spectra for Spec-Driven Development(SDD). Specs live in `openspec/specs/`, change proposals in `openspec/changes/`.

## Use `/spectra:*` skills when:

- A discussion needs structure before coding → `/spectra:discuss`
- User wants to plan, propose, or design a change → `/spectra:propose`
- Tasks are ready to implement → `/spectra:apply`
- There's an in-progress change to continue → `/spectra:ingest`
- User asks about specs or how something works → `/spectra:ask`
- Implementation is done → `/spectra:archive`

## Workflow

discuss? → propose → apply ⇄ ingest → archive

- `discuss` is optional — skip if requirements are clear
- Requirements change mid-work? Plan mode → `ingest` → resume `apply`

## Parked Changes

Changes can be parked（暫存）— temporarily moved out of `openspec/changes/`. Parked changes won't appear in `spectra list` but can be found with `spectra list --parked`. To restore: `spectra unpark <name>`. The `/spectra:apply` and `/spectra:ingest` skills handle parked changes automatically.
<!-- SPECTRA:END -->

# MacLaw

macOS-native AI agent runtime. Swift, zero Node.js dependencies.

## CLI Design Principles

### Mac-native style

Follow macOS CLI conventions (`defaults`, `launchctl`, `networksetup`):
- Flat and direct — prefer `maclaw backend status` over `maclaw backend models list status`
- Verb-noun pattern — `maclaw cron add`, `maclaw message send`
- No unnecessary nesting — one or two levels of subcommands max
- JSON output for machine consumption, human-readable for interactive use

### Zero manual configuration for models

MacLaw does NOT maintain its own model list. Model discovery is delegated entirely to the backend CLI:
- **Codex**: reads `~/.codex/config.toml` for model and auth status
- **Claude**: reads `~/.claude/settings.json` for model and auth status
- Users change models via the backend's own config (`codex` or `claude` settings), not via MacLaw
- `maclaw backend status` reads FROM the backend config, never duplicates it
- `/model set <name>` is a runtime override only (not persisted), resets on restart

### Backend as a swappable adapter

MacLaw supports multiple LLM backends. Each backend is a CLI tool that MacLaw shells out to:

| Backend | CLI | Non-interactive | Install | Login |
|---------|-----|-----------------|---------|-------|
| codex | `codex exec "prompt" -o file` | Yes | `brew install codex` | `codex --login` |
| claude | `claude -p "prompt" --output-format text` | Yes | `brew install claude` | `claude login` |

Config (`~/.maclaw/maclaw.json`):
```json
{
  "backend": "codex",
  "telegram": { ... }
}
```

`maclaw setup` handles backend selection, installation, and login. After setup, MacLaw reads everything it needs from the backend's own config files.

## CLI Command Structure (Target)

```
maclaw setup                    # First-time setup (backend + telegram + daemon)
maclaw gateway run|stop|restart|status

maclaw backend status           # Show active backend, model, auth
maclaw backend set codex|claude # Switch backend
maclaw backend login            # Run backend's login flow

maclaw agent -m "prompt"        # One-shot agent turn (no gateway needed)
maclaw message send -to <chat> -m "text"  # Send Telegram message directly

maclaw cron list                # List scheduled jobs
maclaw cron add                 # Add a job
maclaw cron rm <id>             # Remove a job

maclaw secrets set|delete|list  # Keychain management
maclaw daemon install|uninstall|status
```

## Architecture

```
Telegram ←→ Gateway ←→ Backend CLI (codex exec / claude -p)
                 │
            Cron Scheduler
```

MacLaw is a bridge/orchestrator. It does NOT:
- Call LLM APIs directly (delegate to backend CLI)
- Manage OAuth tokens (delegate to backend CLI)
- Maintain a model catalog (read from backend config)
- Implement its own agent logic (delegate to backend CLI)

## Key Files

| File | Purpose |
|------|---------|
| `Sources/MacLaw/MacLaw.swift` | CLI entry point |
| `Sources/MacLaw/Gateway/` | Gateway commands + runner |
| `Sources/MacLaw/Telegram/` | Bot API, poller, sender, commands, access control |
| `Sources/MacLaw/Agent/CodexCLI.swift` | Codex backend adapter |
| `Sources/MacLaw/Agent/CurrentModel.swift` | Runtime model override |
| `Sources/MacLaw/Security/` | Keychain, config loader, setup wizard |
| `Sources/MacLaw/Cron/` | Job scheduler + state persistence |
| `Sources/MacLaw/Daemon/` | launchd plist management |
| `Sources/MacLaw/Types/Config.swift` | Config types |

## Build & Deploy

```bash
swift build -c release
scp .build/release/maclaw <host>:~/maclaw-tmp
ssh <host> "sudo mv ~/maclaw-tmp /usr/local/bin/maclaw && sudo chmod +x /usr/local/bin/maclaw"
ssh <host> "launchctl kickstart -k gui/501/ai.psychquant.maclaw"
```

## Dependencies

- swift-argument-parser 1.3+ (CLI only)
- No other external Swift packages
