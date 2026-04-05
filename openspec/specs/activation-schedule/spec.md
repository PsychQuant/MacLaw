# activation-schedule Specification

## Purpose

TBD - created by archiving change 'activation-orchestration'. Update Purpose after archive.

## Requirements

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


<!-- @trace
source: activation-orchestration
updated: 2026-03-19
code:
  - .github/skills/spectra-apply/SKILL.md
  - Tests/MacLawTests/PipelineRunnerTests.swift
  - .agents/skills/spectra-debug/SKILL.md
  - Sources/MacLaw/MacLaw.swift
  - Tests/MacLawTests/CronParserTests.swift
  - .github/prompts/spectra-propose.prompt.md
  - .github/skills/spectra-archive/SKILL.md
  - Sources/MacLaw/Gateway/GatewayRunner.swift
  - .agents/skills/spectra-apply/SKILL.md
  - .agents/skills/spectra-propose/SKILL.md
  - Sources/MacLaw/Activation/ActivationEngine.swift
  - .github/skills/spectra-audit/SKILL.md
  - Sources/MacLaw/Activation/ActivationTypes.swift
  - .github/prompts/spectra-ask.prompt.md
  - Sources/MacLaw/Activation/ActivationCommands.swift
  - .github/skills/spectra-debug/SKILL.md
  - Sources/MacLaw/Pipeline/PipelineCommands.swift
  - .agents/skills/spectra-audit/SKILL.md
  - Sources/MacLaw/Pipeline/PipelineTypes.swift
  - .github/skills/spectra-ask/SKILL.md
  - .agents/skills/spectra-ingest/SKILL.md
  - Sources/MacLaw/Types/Config.swift
  - .github/prompts/spectra-ingest.prompt.md
  - Sources/MacLaw/Pipeline/PipelineRunner.swift
  - .github/skills/spectra-discuss/SKILL.md
  - .github/prompts/spectra-audit.prompt.md
  - .github/skills/spectra-ingest/SKILL.md
  - Sources/MacLaw/Activation/CronParser.swift
  - .github/prompts/spectra-debug.prompt.md
  - .github/prompts/spectra-discuss.prompt.md
  - .github/prompts/spectra-apply.prompt.md
  - .agents/skills/spectra-discuss/SKILL.md
  - .agents/skills/spectra-ask/SKILL.md
  - .github/prompts/spectra-archive.prompt.md
  - .github/skills/spectra-propose/SKILL.md
  - .agents/skills/spectra-archive/SKILL.md
-->

---
### Requirement: One-shot schedule

The system SHALL support schedule activations with a specific ISO8601 datetime. After firing once, the activation SHALL mark itself as completed and not fire again.

#### Scenario: One-shot at future time

- **WHEN** an activation is configured with type "schedule", schedule "at 2026-04-01T10:00:00Z"
- **THEN** the activation fires once at that time and marks itself completed

#### Scenario: One-shot time already passed

- **WHEN** an activation is configured with a datetime in the past
- **THEN** the activation fires immediately and marks itself completed

<!-- @trace
source: activation-orchestration
updated: 2026-03-19
code:
  - .github/skills/spectra-apply/SKILL.md
  - Tests/MacLawTests/PipelineRunnerTests.swift
  - .agents/skills/spectra-debug/SKILL.md
  - Sources/MacLaw/MacLaw.swift
  - Tests/MacLawTests/CronParserTests.swift
  - .github/prompts/spectra-propose.prompt.md
  - .github/skills/spectra-archive/SKILL.md
  - Sources/MacLaw/Gateway/GatewayRunner.swift
  - .agents/skills/spectra-apply/SKILL.md
  - .agents/skills/spectra-propose/SKILL.md
  - Sources/MacLaw/Activation/ActivationEngine.swift
  - .github/skills/spectra-audit/SKILL.md
  - Sources/MacLaw/Activation/ActivationTypes.swift
  - .github/prompts/spectra-ask.prompt.md
  - Sources/MacLaw/Activation/ActivationCommands.swift
  - .github/skills/spectra-debug/SKILL.md
  - Sources/MacLaw/Pipeline/PipelineCommands.swift
  - .agents/skills/spectra-audit/SKILL.md
  - Sources/MacLaw/Pipeline/PipelineTypes.swift
  - .github/skills/spectra-ask/SKILL.md
  - .agents/skills/spectra-ingest/SKILL.md
  - Sources/MacLaw/Types/Config.swift
  - .github/prompts/spectra-ingest.prompt.md
  - Sources/MacLaw/Pipeline/PipelineRunner.swift
  - .github/skills/spectra-discuss/SKILL.md
  - .github/prompts/spectra-audit.prompt.md
  - .github/skills/spectra-ingest/SKILL.md
  - Sources/MacLaw/Activation/CronParser.swift
  - .github/prompts/spectra-debug.prompt.md
  - .github/prompts/spectra-discuss.prompt.md
  - .github/prompts/spectra-apply.prompt.md
  - .agents/skills/spectra-discuss/SKILL.md
  - .agents/skills/spectra-ask/SKILL.md
  - .github/prompts/spectra-archive.prompt.md
  - .github/skills/spectra-propose/SKILL.md
  - .agents/skills/spectra-archive/SKILL.md
-->