# MacLaw Positioning

## What MacLaw is

**A minimal, macOS-native Telegram bridge for local Claude / Codex CLI agents.**

That's it. Not a platform. Not a framework. A thin, auditable wrapper that:

1. Long-polls Telegram Bot API
2. Routes messages to `claude -p` or `codex exec` subprocesses
3. Returns the output back to Telegram
4. Manages per-chat sessions, permissions, and liveness

## What MacLaw is not

- Not a multi-platform bot framework (no Discord, Slack, Matrix)
- Not a plugin ecosystem (no MCP, no skills, no canvas)
- Not a replacement for OpenClaw or similar full-featured agent runtimes
- Not trying to compete on feature breadth

## Niche

Target user: someone who wants a Telegram-controlled Claude/Codex CLI agent, and who
values these specific properties over feature breadth:

- **Zero npm dependencies** — the entire runtime is a single Swift binary
- **Auditable** — 38 Swift files, no transitive dep explosion
- **macOS-native** — handles TCC permissions, launchd integration natively
- **Single-binary deployment** — scp + launchctl load, done
- **Owned end-to-end** — bugs are fixable without waiting for upstream

## Comparison

### MacLaw vs OpenClaw

OpenClaw is a full-featured agent runtime. MacLaw is a thin Telegram bridge.
They solve different problems:

| Dimension | MacLaw | OpenClaw |
|-----------|--------|----------|
| Runtime | Swift binary | Node.js (55+ deps) |
| Channels | Telegram only | Telegram, Discord, Slack, ... |
| Backends | Claude CLI, Codex CLI | Many providers, MCP, skills |
| Features | Minimal | Canvas, browser, cron, plugins |
| Failure surface | Small | Large (as we saw with grammy removal in 2026.4.2) |
| Blast radius of breakage | Low | Higher |

If you need breadth, use OpenClaw. If you need a minimal trusted bridge, use MacLaw.

### MacLaw vs telegram-bot-mcp (MCP server)

Different architectural layers entirely:

| | MacLaw | telegram-bot-mcp |
|---|--------|-------------------|
| Form | Always-on daemon | MCP tool for Claude Code sessions |
| Lifecycle | 24/7 | Active only during interactive Claude Code sessions |
| Role | Bot server (receives, responds) | API wrapper (Claude Code calls it) |
| Session state | Per-chat history | None |

MacLaw is an **application**. telegram-bot-mcp is a **tool**. They complement each
other — use telegram-bot-mcp from your laptop to query/send messages during
Claude Code sessions, use MacLaw as the always-on bot on your Mac mini.

## Design principles

### 1. Resist feature creep

Every new feature erodes the "minimal" value proposition. Before adding anything:
- Does it belong in a thin Telegram bridge?
- Can this live in the Claude/Codex CLI tool layer instead?
- Would adding this take MacLaw into OpenClaw territory (where we lose)?

### 2. No runtime dependencies beyond Swift toolchain + Claude/Codex CLI

If a feature requires a new language runtime, database, or large library, reconsider.

### 3. Fail loud, not silent

Better to crash with a clear error than silently degrade. macOS-native means we
know exactly when permissions are missing, when ports are in use, when processes
hang.

### 4. The liveness problem is the main innovation

OpenClaw's blocking gateway problem (backend process stuck → entire bot unresponsive)
is what `TaskMonitor` + `BackendTask` solve. This is MacLaw's actual differentiation.
Guard it carefully.

## Anti-features (things MacLaw will not add)

- Plugin system
- MCP server support
- Non-Telegram channels
- Web UI / dashboard
- Database-backed state
- Multi-tenancy
- Cloud deployment
