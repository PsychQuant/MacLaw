## Context

MacLaw's `GatewayRunner.handleMessage` currently calls `backend.run()` synchronously — the entire gateway blocks until `claude -p` or `codex exec` finishes. If the backend process hangs (CPU at 0%, stuck on a filesystem scan or network call), the gateway cannot process any other messages.

Current flow:
```
Telegram message → handleMessage → await backend.run() → [BLOCKS] → send reply
```

## Goals / Non-Goals

**Goals:**

- Gateway never blocks on a backend call
- Stuck processes are detected and killed automatically
- Long-running tasks (30+ min) are allowed as long as they're making progress
- Results are delivered to Telegram when tasks complete

**Non-Goals:**

- Fixed timeout — explicitly rejected. Agent capability should not be limited by time.
- Retry logic — if a task is stuck and killed, the user can ask again
- Queue/priority system — one task per message is fine for now
- Changing the Backend protocol's `run()` method — keep it for synchronous use cases (CLI `maclaw agent`)

## Decisions

### 1. Spawn instead of await

Add `spawn()` to the Backend protocol. It launches the process, redirects stdout/stderr to temp files, and returns a `BackendTask` handle immediately. The gateway doesn't wait.

```
Telegram message → handleMessage → backend.spawn() → return immediately
                                        ↓
                              TaskMonitor polls every 60s
                                        ↓
                              Process done → read output → send Telegram
                              CPU idle 10min → kill → log (silent)
```

### 2. Liveness detection, not timeout

The `TaskMonitor` checks CPU usage via `ps -p <pid> -o %cpu=` every 60 seconds. A process with CPU > 0.1% is considered alive. A process with CPU = 0% for `livenessIdleMinutes` consecutive checks is considered stuck.

This correctly handles:
- Long tasks that are actively working → not killed
- Stuck processes with zero CPU → killed after idle threshold

### 3. Silent recovery

When a stuck process is killed, no error message is sent to the user. The rationale: sending "timeout error" is misleading (it wasn't a timeout) and unhelpful. The user's experience is simply that the bot didn't respond — they can ask again, just like a human who didn't reply.

### 4. Output parsing in completion callback

Since stdout is redirected to a file, parsing happens in `handleTaskComplete` instead of in the Backend. This keeps the Backend's `spawn()` simple (just launch the process) and moves output interpretation to the gateway layer.

## Risks / Trade-offs

| Risk | Mitigation |
|------|-----------|
| CPU check via `ps` may not be accurate for all hang types | Covers the two observed cases (find scan, network wait). Can add more signals later. |
| Temp files not cleaned up on crash | `BackendTask.cleanup()` removes files. Gateway crash → files in /tmp, cleaned by OS on reboot. |
| Multiple concurrent tasks for same chat | Allowed — each task is independent. Last one to complete wins. Acceptable for now. |
| `Process` reference not held → can't kill | `BackendTask` stores PID directly, uses `kill()` syscall. No Process reference needed. |
