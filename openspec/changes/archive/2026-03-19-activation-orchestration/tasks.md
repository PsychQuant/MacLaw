## 1. Activation Layer Foundation (two-layer separation: activation and pipeline are independent)

- [x] 1.1 Define Activation types and config schema: `ActivationType` enum (.event, .schedule, .interval), `ActivationConfig` Codable struct, and action type (.task, .pipeline) in `Sources/MacLaw/Activation/ActivationTypes.swift`
- [x] 1.2 Implement cron expression parsing: 5-field cron parser (minute hour day month weekday) in `Sources/MacLaw/Activation/CronParser.swift` — pure Swift, no external deps (spec: Cron expression scheduling)
- [x] 1.3 Evolve CronScheduler into ActivationEngine: rename to `Sources/MacLaw/Activation/ActivationEngine.swift`, add event and schedule support while keeping interval and backoff logic (backward compatible cron syntax)

## 2. Activation Primitives

- [x] 2.1 Implement duration-based interval activation with drift-from-completion semantics and backoff on consecutive errors (spec: Duration-based interval activation, Backoff on consecutive errors)
- [x] 2.2 Implement activation-schedule: cron expression evaluation, next-fire-time calculation, and one-shot schedule support (spec: Cron expression scheduling, One-shot schedule)
- [x] 2.3 Implement Telegram message pattern activation: regex-based filter on incoming messages using event sources (telegram message patterns and FSEvents), firing with matched context (spec: Telegram message pattern activation)
- [x] 2.4 Implement file system watch activation: DispatchSource.makeFileSystemObjectSource on configured paths, with graceful handling of non-existent paths (spec: File system watch activation)

## 3. Pipeline Engine (pipeline step execution model)

- [x] 3.1 Define Pipeline types: `PipelineConfig`, `PipelineStep`, `ErrorStrategy` (.stop, .skip, .retry) in `Sources/MacLaw/Pipeline/PipelineTypes.swift`
- [x] 3.2 Implement sequential step execution with step error handling: PipelineRunner actor that executes steps in order, passes output between steps, and applies error strategies — stop, skip, retry (spec: Sequential step execution, Step error handling)
- [x] 3.3 Implement template variable interpolation: `{{stepName.output}}` and `{{activation.message}}` replacement in step prompts (spec: Template variable interpolation)

## 4. Config and CLI Integration

- [x] 4.1 Extend `~/.maclaw/maclaw.json` config schema with `activations` and `pipelines` sections, update ConfigLoader to parse them
- [x] 4.2 Add `maclaw activation list/add/rm` CLI commands
- [x] 4.3 Add pipeline management CLI: `maclaw pipeline list/add/rm/run` commands for managing and manually triggering pipelines (spec: Pipeline management CLI)
- [x] 4.4 Map legacy `maclaw cron add --schedule "every Nh"` to activation-interval for backward compatible cron syntax

## 5. Gateway Integration

- [x] 5.1 Wire ActivationEngine into GatewayRunner: start activations on gateway start, stop on shutdown
- [x] 5.2 Wire Telegram event activations into the gateway message loop: incoming messages pass through event activation pattern matching before normal chat handling
- [x] 5.3 Wire pipeline execution: when an activation's action type is "pipeline", look up and execute the referenced pipeline via PipelineRunner

## 6. Testing and Deployment

- [x] 6.1 Write unit tests for cron expression parsing (standard cron vectors, edge cases, invalid expressions)
- [x] 6.2 Write unit tests for PipelineRunner (sequential step execution, step error handling, template variable interpolation)
- [x] 6.3 Cross-build and deploy to PsychQuantClaw, verify activation and pipeline commands via SSH
