# task-monitor

## ADDED Requirements

### Requirement: backend-spawn

The Backend protocol SHALL provide a `spawn()` method that launches the backend process as a detached task.
`spawn()` SHALL redirect process stdout and stderr to temporary files.
`spawn()` SHALL return a `BackendTask` handle containing the PID, chat ID, output file path, and start time.
`spawn()` SHALL NOT block the caller.

### Requirement: liveness-monitoring

The TaskMonitor SHALL check each tracked process every 60 seconds.
The TaskMonitor SHALL read CPU usage via `ps -p <pid> -o %cpu=`.
A process with CPU usage below 0.1% SHALL increment an idle counter.
A process with CPU usage at or above 0.1% SHALL reset the idle counter to zero.
When the idle counter reaches `livenessIdleMinutes` (configurable, default 10), the process SHALL be terminated via SIGTERM followed by SIGKILL after 2 seconds.

### Requirement: completion-callback

When a tracked process exits normally, the TaskMonitor SHALL read the output file and invoke the `onComplete` callback.
The `onComplete` callback SHALL parse the output and send the result to the originating Telegram chat.
Session IDs from the output SHALL be persisted for future message continuity.

### Requirement: silent-recovery

No error message SHALL be sent to the Telegram user when a stuck process is killed.
The event SHALL be logged with the task ID, PID, and idle duration.

### Requirement: cleanup

Temporary output and stderr files SHALL be removed after completion or stuck-kill.
The TaskMonitor SHALL stop its polling loop when no tasks are being tracked.

### Requirement: configuration

`livenessIdleMinutes` SHALL be an optional integer field in `MacLawConfig` with a default value of 10.
