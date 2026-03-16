## ADDED Requirements

### Requirement: Recurring jobs

The system SHALL support recurring cron jobs with an interval specification (e.g., "every 1h", "every 30m"). Each job SHALL have: id, name, prompt, optional model override, and delivery target (Telegram chat ID). The scheduler SHALL execute jobs by sending the prompt to the LLM and delivering the response to the specified Telegram chat.

#### Scenario: Hourly recurring job

- **WHEN** a job is scheduled with "every 1h"
- **THEN** the system executes the job's prompt every hour and delivers the response to the configured Telegram chat

#### Scenario: Job failure with backoff

- **WHEN** a cron job fails (LLM error or delivery failure)
- **THEN** the system applies exponential backoff (30s, 1m, 5m, 15m, 60m max) and retries. Successful execution resets the backoff counter.

### Requirement: One-shot jobs

The system SHALL support one-shot jobs scheduled for a specific time. After execution (success or max retries), the job SHALL be marked as completed and not run again.

#### Scenario: Scheduled one-shot

- **WHEN** a job is scheduled with "at 2026-03-17T10:00:00Z"
- **THEN** the system executes it at the specified time and marks it complete

#### Scenario: One-shot max retries

- **WHEN** a one-shot job fails 3 consecutive times
- **THEN** the job is marked as failed and disabled

### Requirement: Job state persistence

The system SHALL persist job state (last run time, consecutive errors, next scheduled time) to `~/.maclaw/cron-state.json`. On restart, the scheduler SHALL resume jobs from persisted state.

#### Scenario: Restart recovery

- **WHEN** the daemon restarts
- **THEN** the scheduler loads persisted state and resumes all enabled jobs at their next scheduled time
