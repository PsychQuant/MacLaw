## Context

MacLaw's current CronScheduler supports two modes: `every Nh` (interval) and `at <ISO8601>` (one-shot). Both are time-driven. There is no event-driven activation (e.g., react to a Telegram message pattern), no cron-expression scheduling (e.g., "every weekday at 9 AM"), and no way to chain multiple steps into a pipeline. The gateway processes each incoming message independently — there is no concept of "if this message matches a pattern, run a sequence of steps."

The two-layer architecture:
- **Activation** (Layer 1): What starts a task — Event, Schedule, or Interval
- **Orchestration** (Layer 2): How tasks compose — Pipeline with sequential steps, branching, error handling

## Goals / Non-Goals

**Goals:**

- Three activation primitives: Event (push-triggered), Schedule (cron/calendar), Interval (duration-based)
- Pipeline engine: chain steps sequentially, pass data between steps, handle errors per step
- Declarative config in `~/.maclaw/maclaw.json` under `activations` and `pipelines` sections
- CLI commands: `maclaw activation list/add/rm`, `maclaw pipeline list/add/rm/run`
- Backward compatible: existing `maclaw cron` commands continue to work (mapped to activation-interval)
- Stay zero-dependency (no external Swift packages beyond swift-argument-parser)

**Non-Goals:**

- No visual workflow editor (CLI and JSON config only)
- No DAG execution (sequential pipelines only in v1 — no parallel branches)
- No distributed execution (all steps run on the same Mac)
- No step retry with exponential backoff in v1 (use activation-level retry from existing CronScheduler)
- No external webhook server (event sources are Telegram messages and file system, not HTTP endpoints)

## Decisions

### Two-layer separation: Activation and Pipeline are independent

An activation can run a single task (backward compatible with current cron) OR start a pipeline. A pipeline is just a named sequence of steps — it doesn't know or care what activated it. This keeps the layers composable: any activation type can trigger any pipeline.

```
activation → (single task | pipeline reference)
pipeline → [step, step, step, ...]
```

Alternatives considered: unified model where pipeline IS the activation (n8n style). Rejected because it couples activation logic with orchestration logic, making both harder to reason about.

### Evolve CronScheduler into ActivationEngine

Rather than replacing CronScheduler, evolve it. The current `CronScheduleType` enum gains a third case (`.event`), and the scheduler learns to register event listeners in addition to timers. The actor-based architecture, state persistence, and backoff logic all carry over.

Alternatives considered: new ActivationEngine from scratch. Rejected because CronScheduler already handles 80% of what's needed (state persistence, error tracking, backoff). Building from scratch would duplicate proven code.

### Event sources: Telegram message patterns and FSEvents

v1 event sources:
1. **Telegram message pattern** — regex or keyword match on incoming messages. The gateway already receives all messages; events are a filter layer.
2. **File system watch** — DispatchSource.makeFileSystemObjectSource on a path. Useful for "new file in ~/Downloads → process it."

No webhook server — MacLaw runs behind NAT on home networks. External events come through Telegram (which already has a polling connection).

### Pipeline step execution model

Steps execute sequentially within a single Swift Task. Each step receives the previous step's output as input (simple string-based data passing). Steps are backend agent calls (same as current cron job execution — shell out to codex/claude CLI).

```swift
struct PipelineStep {
    let name: String
    let prompt: String           // sent to backend CLI
    let onError: ErrorStrategy   // .stop | .skip | .retry(n)
}
```

No parallel step execution in v1. Keep it simple — sequential is enough for the target use cases (fetch → process → reply).

### Config schema

```json
{
  "activations": [
    {
      "id": "daily-summary",
      "type": "schedule",
      "schedule": "0 9 * * *",
      "action": {"type": "pipeline", "pipeline": "morning-briefing"}
    },
    {
      "id": "url-handler",
      "type": "event",
      "event": {"source": "telegram", "pattern": "https?://\\S+"},
      "action": {"type": "pipeline", "pipeline": "url-summarizer"}
    },
    {
      "id": "hourly-check",
      "type": "interval",
      "interval": "1h",
      "action": {"type": "task", "prompt": "check system health"}
    }
  ],
  "pipelines": [
    {
      "id": "url-summarizer",
      "steps": [
        {"name": "fetch", "prompt": "Fetch the content from {{url}}"},
        {"name": "summarize", "prompt": "Summarize: {{fetch.output}}"},
        {"name": "reply", "prompt": "Reply to chat with: {{summarize.output}}"}
      ]
    }
  ]
}
```

### Cron expression parsing

Add cron expression support (5-field: minute hour day month weekday) using a pure-Swift parser. No external library — cron parsing is well-defined and can be implemented in ~100 lines. The existing `every Nh` and `at <date>` syntax remain supported as shortcuts for interval and one-shot schedule.

## Risks / Trade-offs

- [Cron parser correctness] → Keep it simple (5-field only, no extensions like `L`, `W`, `#`). Test with known cron test vectors. Mitigation: start with basic patterns, extend later.
- [Template variable injection in pipeline prompts] → `{{step.output}}` interpolation must not allow prompt injection from step outputs. Mitigation: outputs are always treated as data, never as instructions. Wrap in quotes or use a structured context format.
- [Event pattern matching overhead] → Every incoming Telegram message runs through all event activation patterns. Mitigation: patterns are compiled regexes cached at startup. With typical <10 activations, this is negligible.
- [Backward compatibility] → Existing `maclaw cron add --schedule "every 1h"` must keep working. Mitigation: map `every Nh` to activation-interval, `at <date>` to activation-schedule (one-shot). Add deprecation notice pointing to `maclaw activation add`.
