## ADDED Requirements

### Requirement: launchd plist generation

The system SHALL generate a launchd plist at `~/Library/LaunchAgents/ai.psychquant.maclaw.plist` via `maclaw daemon install`. The plist SHALL configure: auto-start on login, restart on crash, stdout/stderr logging to `~/.maclaw/logs/`, and the gateway run command with configured port.

#### Scenario: Install daemon

- **WHEN** the user runs `maclaw daemon install`
- **THEN** the system generates the plist, loads it via `launchctl`, and confirms the daemon is running

#### Scenario: Uninstall daemon

- **WHEN** the user runs `maclaw daemon uninstall`
- **THEN** the system unloads the plist via `launchctl` and removes the plist file

### Requirement: Daemon status

The system SHALL provide `maclaw daemon status` that reports whether the daemon is loaded, running, its PID, and uptime.

#### Scenario: Daemon running

- **WHEN** the daemon is running
- **THEN** status outputs JSON with `running: true`, `pid`, and `uptime`

#### Scenario: Daemon not installed

- **WHEN** no plist exists
- **THEN** status outputs JSON with `installed: false`
