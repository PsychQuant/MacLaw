## ADDED Requirements

### Requirement: Sequential step execution

The system SHALL support pipelines consisting of ordered steps. Steps SHALL execute sequentially — each step begins only after the previous step completes. Each step SHALL receive the previous step's output as available context.

#### Scenario: Three-step pipeline

- **WHEN** a pipeline is configured with steps [fetch, summarize, reply]
- **AND** the pipeline is activated
- **THEN** fetch runs first, then summarize receives fetch's output, then reply receives summarize's output

#### Scenario: First step receives activation context

- **WHEN** a pipeline is activated by a Telegram event with matched message data
- **THEN** the first step receives the activation context (message text, sender, matched groups) as input

### Requirement: Step error handling

Each pipeline step SHALL have a configurable error strategy: stop (halt the pipeline), skip (continue to next step with empty output), or retry (retry the step up to N times before applying the stop or skip fallback).

#### Scenario: Stop on error (default)

- **WHEN** a step fails and its error strategy is "stop"
- **THEN** the pipeline halts and reports the error

#### Scenario: Skip on error

- **WHEN** a step fails and its error strategy is "skip"
- **THEN** the pipeline continues to the next step with the failed step's output set to empty

#### Scenario: Retry then stop

- **WHEN** a step fails and its error strategy is "retry" with max 2
- **AND** the step fails on all retry attempts
- **THEN** the pipeline halts after exhausting retries

### Requirement: Template variable interpolation

Pipeline step prompts SHALL support `{{variable}}` template syntax for referencing activation context and previous step outputs. The system SHALL replace `{{stepName.output}}` with the actual output of the named step before sending the prompt to the backend CLI.

#### Scenario: Reference previous step output

- **WHEN** a step prompt contains `{{fetch.output}}`
- **AND** the step named "fetch" completed with output "page content here"
- **THEN** the prompt sent to the backend CLI contains "page content here" in place of `{{fetch.output}}`

#### Scenario: Reference activation context

- **WHEN** a step prompt contains `{{activation.message}}`
- **AND** the pipeline was activated by a Telegram message "check this URL"
- **THEN** the prompt contains "check this URL" in place of `{{activation.message}}`

### Requirement: Pipeline management CLI

The system SHALL provide `maclaw pipeline list`, `maclaw pipeline add`, `maclaw pipeline rm`, and `maclaw pipeline run` commands for managing and manually triggering pipelines.

#### Scenario: List pipelines

- **WHEN** user runs `maclaw pipeline list`
- **THEN** the system outputs all configured pipelines with their step count

#### Scenario: Manual pipeline run

- **WHEN** user runs `maclaw pipeline run --id url-summarizer --context "https://example.com"`
- **THEN** the pipeline executes with the provided context, regardless of activation configuration
