## Why

MacLaw's backend calls (`claude -p`, `codex exec`) block the gateway indefinitely when the AI process hangs. This has happened twice in two days — processes stuck for 20 minutes and 4.5 hours with CPU at 0%. During this time, the gateway cannot process any other Telegram messages. The root cause is synchronous `Process` execution with no liveness detection.

Traditional timeout-based solutions would limit the agent's capability — some tasks legitimately take 30+ minutes. Instead, we replace blocking execution with a liveness-based approach: spawn processes as detached tasks, monitor their CPU activity, and only kill truly stuck processes (CPU idle for extended periods).

## What Changes

- Backend processes are spawned as detached tasks (nohup-style) instead of blocking the gateway
- A TaskMonitor watches all running backend processes for liveness (CPU activity)
- Processes with CPU=0% for a configurable period are considered stuck and killed
- Gateway returns immediately after spawning, freeing it to handle other messages
- Completion callbacks deliver results to Telegram when tasks finish

## Capabilities

### New Capabilities

- `task-monitor`: Background liveness monitoring for spawned backend processes. Detects stuck processes via CPU idle detection and kills them. Tracks active tasks and delivers results on completion.

### Modified Capabilities

(none — this changes how backends are invoked, not what they do)

## Impact

- Affected code: `ClaudeCLI.swift`, `CodexCLI.swift`, `Backend.swift`, `GatewayRunner.swift`, `Config.swift`
- New files: `BackendTask.swift`, `TaskMonitor.swift`
- Config: new optional `livenessIdleMinutes` field in `maclaw.json`
- GitHub Issue: PsychQuant/MacLaw#1
