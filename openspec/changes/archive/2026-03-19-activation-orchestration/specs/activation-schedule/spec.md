## ADDED Requirements

### Requirement: Cron expression scheduling

The system SHALL support schedule activations using 5-field cron expressions (minute, hour, day-of-month, month, day-of-week). The system SHALL evaluate cron expressions against the current time and fire the activation at the next matching time point.

#### Scenario: Daily at 9 AM

- **WHEN** an activation is configured with type "schedule", schedule "0 9 * * *"
- **THEN** the activation fires at 09:00 every day

#### Scenario: Weekday-only schedule

- **WHEN** an activation is configured with schedule "0 9 * * 1-5"
- **THEN** the activation fires at 09:00 Monday through Friday only

#### Scenario: Invalid cron expression

- **WHEN** an activation is configured with an unparseable cron expression
- **THEN** the system logs an error and skips the activation without crashing

### Requirement: One-shot schedule

The system SHALL support schedule activations with a specific ISO8601 datetime. After firing once, the activation SHALL mark itself as completed and not fire again.

#### Scenario: One-shot at future time

- **WHEN** an activation is configured with type "schedule", schedule "at 2026-04-01T10:00:00Z"
- **THEN** the activation fires once at that time and marks itself completed

#### Scenario: One-shot time already passed

- **WHEN** an activation is configured with a datetime in the past
- **THEN** the activation fires immediately and marks itself completed
