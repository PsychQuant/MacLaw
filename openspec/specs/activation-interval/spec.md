# activation-interval Specification

## Purpose

TBD - created by archiving change 'activation-orchestration'. Update Purpose after archive.

## Requirements

### Requirement: Duration-based interval activation

The system SHALL support interval activations that fire every N time units measured from the completion of the previous run. The interval SHALL be specified as a duration string (e.g., "30s", "5m", "1h", "1d"). The interval timer SHALL start after the previous execution completes, not from a fixed clock point.

#### Scenario: Every hour interval

- **WHEN** an activation is configured with type "interval", interval "1h"
- **THEN** the activation fires, and after completion, waits 1 hour before firing again

#### Scenario: Drift behavior

- **WHEN** an interval activation is configured with interval "5m"
- **AND** the task execution takes 2 minutes
- **THEN** the next activation fires 5 minutes after the task completes (7 minutes wall-clock from start), not at a fixed 5-minute interval from start


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
### Requirement: Backoff on consecutive errors

The system SHALL apply exponential backoff when an interval activation fails consecutively. The backoff delay SHALL be added to the normal interval. A successful execution SHALL reset the consecutive error count and backoff.

#### Scenario: Backoff after failures

- **WHEN** an interval activation fails 3 times consecutively
- **THEN** the next run is delayed by the interval plus the backoff delay for 3 consecutive errors

#### Scenario: Success resets backoff

- **WHEN** an interval activation has accumulated consecutive errors
- **AND** the next execution succeeds
- **THEN** the consecutive error count resets to zero and subsequent runs use the normal interval


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
### Requirement: Backward compatible cron syntax

The system SHALL accept "every Nh" and "every Nm" syntax from the existing cron system and map them to interval activations. The `maclaw cron add --schedule "every 1h"` command SHALL continue to work.

#### Scenario: Legacy cron syntax

- **WHEN** a user runs `maclaw cron add --schedule "every 1h" --prompt "check health"`
- **THEN** the system creates an interval activation with interval "1h"

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