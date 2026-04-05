import Foundation

/// Manages all activations — interval, schedule, and event — with state persistence and backoff.
/// Evolved from CronScheduler. Event activations are driven externally via `handleEvent(_:)`.
actor ActivationEngine {
    private var activations: [ActivationConfig] = []
    private var state: ActivationState
    private var timers: [String: DispatchSourceTimer] = [:]
    private var fsWatchers: [String: DispatchSourceFileSystemObject] = [:]
    private var compiledPatterns: [String: NSRegularExpression] = [:]
    private let stateFilePath: String
    private let execute: @Sendable (ActivationConfig, ActivationContext) async -> Result<String, Error>

    init(
        activations: [ActivationConfig],
        execute: @Sendable @escaping (ActivationConfig, ActivationContext) async -> Result<String, Error>
    ) {
        self.activations = activations
        self.stateFilePath = "\(ConfigLoader.configDir)/activation-state.json"
        self.execute = execute

        if let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)),
           let saved = try? JSONDecoder().decode(ActivationState.self, from: data) {
            self.state = saved
        } else {
            self.state = ActivationState(activations: [:])
        }
    }

    func start() {
        for activation in activations where activation.isEnabled {
            let id = activation.id

            if state.activations[id] == nil {
                state.activations[id] = ActivationRunState(
                    consecutiveErrors: 0, enabled: true, completed: false
                )
            }

            guard state.activations[id]?.enabled == true,
                  state.activations[id]?.completed != true else { continue }

            switch activation.type {
            case .interval:
                guard let intervalStr = activation.interval,
                      let seconds = parseInterval(intervalStr) else {
                    log("Invalid interval for '\(id)': \(activation.interval ?? "nil")")
                    continue
                }
                scheduleInterval(id: id, activation: activation, seconds: seconds)

            case .schedule:
                guard let schedule = activation.schedule else {
                    log("Missing schedule for '\(id)'")
                    continue
                }
                scheduleCalendar(id: id, activation: activation, schedule: schedule)

            case .event:
                registerEvent(id: id, activation: activation)
            }
        }
        log("Activation engine started with \(activations.count) activations")
    }

    func stop() {
        for (_, timer) in timers { timer.cancel() }
        timers.removeAll()
        for (_, watcher) in fsWatchers { watcher.cancel() }
        fsWatchers.removeAll()
        compiledPatterns.removeAll()
        persistState()
    }

    // MARK: - External event handling

    /// Called by gateway when a Telegram message arrives. Returns true if any activation fired.
    func handleTelegramMessage(chatId: String, senderId: String, text: String) async -> Bool {
        var fired = false
        for activation in activations where activation.type == .event && activation.isEnabled {
            guard let event = activation.event, event.source == .telegram else { continue }
            guard let regex = compiledPatterns[activation.id] else { continue }

            let range = NSRange(text.startIndex..., in: text)
            guard let match = regex.firstMatch(in: text, range: range) else { continue }

            var groups: [String] = []
            for i in 0..<match.numberOfRanges {
                if let r = Range(match.range(at: i), in: text) {
                    groups.append(String(text[r]))
                }
            }

            let context = ActivationContext.telegram(id: activation.id, message: text, groups: groups)
            await runActivation(id: activation.id, activation: activation, context: context)
            fired = true
        }
        return fired
    }

    // MARK: - Interval

    private func scheduleInterval(id: String, activation: ActivationConfig, seconds: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + seconds, repeating: seconds)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.runActivation(id: id, activation: activation, context: .empty(id: id)) }
        }
        timer.resume()
        timers[id] = timer
        log("Scheduled interval '\(id)' every \(Int(seconds))s")
    }

    // MARK: - Schedule (cron + one-shot)

    private func scheduleCalendar(id: String, activation: ActivationConfig, schedule: String) {
        // One-shot: "at <ISO8601>"
        if schedule.hasPrefix("at ") {
            let dateStr = String(schedule.dropFirst(3))
            guard let date = ISO8601DateFormatter().date(from: dateStr) else {
                log("Invalid one-shot date for '\(id)': \(dateStr)")
                return
            }
            let delay = max(date.timeIntervalSinceNow, 0)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                Task {
                    await self.runActivation(id: id, activation: activation, context: .empty(id: id))
                    await self.markCompleted(id: id)
                }
            }
            log("Scheduled one-shot '\(id)' at \(dateStr)")
            return
        }

        // Cron expression
        guard let cron = CronExpression.parse(schedule) else {
            log("Invalid cron expression for '\(id)': \(schedule)")
            return
        }

        scheduleCronTick(id: id, activation: activation, cron: cron)
    }

    private func scheduleCronTick(id: String, activation: ActivationConfig, cron: CronExpression) {
        guard let nextFire = cron.nextFireTime(after: Date()) else {
            log("No next fire time for '\(id)' within 366 days")
            return
        }

        let delay = max(nextFire.timeIntervalSinceNow, 0)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            Task {
                await self.runActivation(id: id, activation: activation, context: .empty(id: id))
                // Reschedule for next fire time
                await self.scheduleCronTick(id: id, activation: activation, cron: cron)
            }
        }
        let formatter = ISO8601DateFormatter()
        log("Scheduled cron '\(id)' next fire: \(formatter.string(from: nextFire))")
    }

    // MARK: - Event registration

    private func registerEvent(id: String, activation: ActivationConfig) {
        guard let event = activation.event else {
            log("Missing event config for '\(id)'")
            return
        }

        switch event.source {
        case .telegram:
            guard let regex = try? NSRegularExpression(pattern: event.pattern) else {
                log("Invalid regex for '\(id)': \(event.pattern)")
                return
            }
            compiledPatterns[id] = regex
            log("Registered telegram event '\(id)' pattern: \(event.pattern)")

        case .fswatch:
            let path = (event.pattern as NSString).expandingTildeInPath
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else {
                log("Warning: Cannot watch path '\(path)' for '\(id)' — path does not exist")
                return
            }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete],
                queue: DispatchQueue.global()
            )
            source.setEventHandler { [weak self] in
                guard let self else { return }
                let context = ActivationContext.fileWatch(id: id, path: path)
                Task { await self.runActivation(id: id, activation: activation, context: context) }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            fsWatchers[id] = source
            log("Registered fswatch event '\(id)' path: \(path)")
        }
    }

    // MARK: - Execution

    private func runActivation(id: String, activation: ActivationConfig, context: ActivationContext) async {
        let result = await execute(activation, context)

        switch result {
        case .success:
            state.activations[id]?.lastRunAt = ISO8601DateFormatter().string(from: Date())
            state.activations[id]?.consecutiveErrors = 0
            state.activations[id]?.lastError = nil
            log("Activation '\(id)' succeeded")

        case .failure(let error):
            let errors = (state.activations[id]?.consecutiveErrors ?? 0) + 1
            state.activations[id]?.consecutiveErrors = errors
            state.activations[id]?.lastError = error.localizedDescription
            log("Activation '\(id)' failed (consecutive: \(errors)): \(error.localizedDescription)")
        }

        persistState()
    }

    private func markCompleted(id: String) {
        state.activations[id]?.completed = true
        persistState()
    }

    // MARK: - Helpers

    private func parseInterval(_ value: String) -> TimeInterval? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Support legacy "every Nh" format
        let normalized = trimmed.hasPrefix("every ") ? String(trimmed.dropFirst(6)) : trimmed

        guard let suffix = normalized.last else { return nil }
        guard let number = Double(normalized.dropLast()) else { return nil }
        switch suffix {
        case "s": return number
        case "m": return number * 60
        case "h": return number * 3600
        case "d": return number * 86400
        default: return nil
        }
    }

    private func persistState() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: URL(fileURLWithPath: stateFilePath))
        } catch {
            log("Failed to persist activation state: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [activation] \(message)")
    }
}
