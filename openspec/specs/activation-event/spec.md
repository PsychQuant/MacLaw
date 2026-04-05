# activation-event Specification

## Purpose

TBD - created by archiving change 'activation-orchestration'. Update Purpose after archive.

## Requirements

### Requirement: Telegram message pattern activation

The system SHALL support event activations that trigger when an incoming Telegram message matches a configured pattern. The pattern SHALL be a regular expression applied to the message text. When matched, the activation SHALL execute its configured action (single task or pipeline) with the matched message context available as input.

#### Scenario: URL pattern triggers pipeline

- **WHEN** an activation is configured with type "event", source "telegram", pattern `https?://\S+`
- **AND** a Telegram message containing "check this https://example.com" is received
- **THEN** the activation fires with the matched URL available as context data

#### Scenario: Pattern does not match

- **WHEN** an activation is configured with a telegram pattern `^/report`
- **AND** a Telegram message "hello everyone" is received
- **THEN** the activation does NOT fire

#### Scenario: Multiple event activations

- **WHEN** two event activations are configured with different patterns
- **AND** an incoming message matches both patterns
- **THEN** both activations fire independently


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
### Requirement: File system watch activation

The system SHALL support event activations that trigger when a file or directory changes at a configured path. The watch SHALL use macOS DispatchSource file system events.

#### Scenario: New file in watched directory

- **WHEN** an activation is configured with type "event", source "fswatch", path "~/Downloads"
- **AND** a new file appears in ~/Downloads
- **THEN** the activation fires with the file path available as context data

#### Scenario: Watched path does not exist

- **WHEN** an activation is configured with an fswatch path that does not exist
- **THEN** the system logs a warning and skips the activation without crashing

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