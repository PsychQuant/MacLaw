## 1. Core Types

- [x] 1.1 Create `BackendTask` struct with PID tracking, CPU check, output reading, terminate, cleanup
- [x] 1.2 Create `TaskMonitor` actor with liveness polling loop, onComplete/onStuck callbacks

## 2. Backend spawn

- [x] 2.1 Add `spawn()` method to `Backend` protocol
- [x] 2.2 Implement `spawn()` in `ClaudeCLI.swift` — launch process, redirect output to temp files
- [x] 2.3 Implement `spawn()` in `CodexCLI.swift` — launch process, redirect output to temp files

## 3. Gateway integration

- [x] 3.1 Initialize `TaskMonitor` in `GatewayRunner.run()`
- [x] 3.2 Replace blocking `backend.run()` with `backend.spawn()` + `monitor.track()` in `handleMessage`
- [x] 3.3 Implement `handleTaskComplete` — parse output, send Telegram reply, update session
- [x] 3.4 Implement `handleTaskStuck` — log event, silent recovery
- [x] 3.5 Stop TaskMonitor in `GatewayRunner.stop()`

## 4. Config

- [x] 4.1 Add `livenessIdleMinutes` to `MacLawConfig`

## 5. Validation

- [ ] 5.1 Build and verify no compiler errors
- [ ] 5.2 Deploy to PsychQuantClaw and test with a Telegram message
- [ ] 5.3 Verify stuck process detection by sending a message that triggers a long operation
