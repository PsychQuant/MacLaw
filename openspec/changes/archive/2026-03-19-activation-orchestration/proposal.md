## Why

MacLaw currently has basic cron scheduling (CronScheduler) but lacks a proper activation model and has no orchestration capability. Tasks can only be triggered by time intervals — there is no event-driven activation, no calendar-based scheduling, and no way to chain tasks into multi-step pipelines. This limits MacLaw to simple periodic jobs and makes it impossible to build workflows like "when a Telegram message mentions a URL → fetch it → summarize → reply." Adding a two-layer architecture (Activation + Orchestration) gives MacLaw the expressiveness of systems like Airflow and n8n while staying true to its Mac-native, zero-dependency design.

## What Changes

- New Activation layer with three primitives: Event (external push triggers), Schedule (cron/calendar-based), and Interval (duration-based, replaces current CronScheduler)
- New Orchestration layer: Pipeline engine that chains steps, supports branching and error handling
- Pipelines are activated by any of the three activation primitives
- Activation and orchestration are configured in `~/.maclaw/maclaw.json` (declarative) or via CLI commands
- Existing `maclaw cron add` evolves to support all three activation types
- **BREAKING**: CronScheduler internals change, but `maclaw cron` CLI surface stays compatible

## Capabilities

### New Capabilities

- `activation-event`: Event-driven activation — Telegram message patterns, webhook, file system watch triggers that start a task or pipeline
- `activation-schedule`: Calendar-based activation — cron expressions and calendar intervals that fire at absolute time points
- `activation-interval`: Duration-based activation — run every N seconds/minutes/hours from last completion (replaces current CronScheduler's interval mode)
- `pipeline-engine`: Multi-step task orchestration — sequential steps, conditional branching, error handling, step-to-step data passing

### Modified Capabilities

(none — no existing specs)

## Impact

- Affected code: `Sources/MacLaw/Cron/` (CronScheduler, CronJob) — evolves into activation layer
- New code: `Sources/MacLaw/Activation/` (Event, Schedule, Interval primitives)
- New code: `Sources/MacLaw/Pipeline/` (Pipeline engine, Step, branching)
- Config: `~/.maclaw/maclaw.json` gains `activations` and `pipelines` sections
- CLI: `maclaw cron` commands extended; new `maclaw pipeline` commands
- No new Swift dependencies (stays zero-dep except swift-argument-parser)
