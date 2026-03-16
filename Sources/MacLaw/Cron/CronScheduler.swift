import Foundation

/// Manages cron jobs — recurring and one-shot — with state persistence and backoff.
actor CronScheduler {
    private var jobs: [CronJobConfig] = []
    private var state: CronJobState
    private var timers: [String: DispatchSourceTimer] = [:]
    private let stateFilePath: String
    private let execute: @Sendable (CronJobConfig) async -> Result<String, Error>

    init(
        jobs: [CronJobConfig],
        execute: @Sendable @escaping (CronJobConfig) async -> Result<String, Error>
    ) {
        self.jobs = jobs
        self.stateFilePath = "\(ConfigLoader.configDir)/cron-state.json"
        self.execute = execute

        // Load persisted state or create fresh
        if let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)),
           let saved = try? JSONDecoder().decode(CronJobState.self, from: data) {
            self.state = saved
        } else {
            self.state = CronJobState(jobs: [:])
        }
    }

    func start() {
        for job in jobs {
            let id = job.id ?? job.name
            guard let schedule = CronJobParser.parseSchedule(job.schedule) else {
                log("Invalid schedule for job '\(id)': \(job.schedule)")
                continue
            }

            // Initialize state if missing
            if state.jobs[id] == nil {
                state.jobs[id] = JobRunState(
                    consecutiveErrors: 0, enabled: true, completed: false
                )
            }

            guard state.jobs[id]?.enabled == true, state.jobs[id]?.completed != true else {
                continue
            }

            switch schedule {
            case .recurring(let interval):
                scheduleRecurring(id: id, job: job, interval: interval)
            case .oneShot(let at):
                scheduleOneShot(id: id, job: job, at: at)
            }
        }
        log("Cron scheduler started with \(jobs.count) jobs")
    }

    func stop() {
        for (_, timer) in timers {
            timer.cancel()
        }
        timers.removeAll()
        persistState()
    }

    // MARK: - Recurring

    private func scheduleRecurring(id: String, job: CronJobConfig, interval: TimeInterval) {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.runJob(id: id, job: job, maxRetries: nil) }
        }
        timer.resume()
        timers[id] = timer
        log("Scheduled recurring job '\(id)' every \(Int(interval))s")
    }

    // MARK: - One-shot

    private func scheduleOneShot(id: String, job: CronJobConfig, at date: Date) {
        let delay = max(date.timeIntervalSinceNow, 0)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            Task { await self.runJob(id: id, job: job, maxRetries: 3) }
        }
        log("Scheduled one-shot job '\(id)' at \(ISO8601DateFormatter().string(from: date))")
    }

    // MARK: - Execution

    private func runJob(id: String, job: CronJobConfig, maxRetries: Int?) {
        Task {
            let result = await execute(job)

            switch result {
            case .success:
                state.jobs[id]?.lastRunAt = ISO8601DateFormatter().string(from: Date())
                state.jobs[id]?.consecutiveErrors = 0
                state.jobs[id]?.lastError = nil
                if maxRetries != nil {
                    state.jobs[id]?.completed = true
                }
                log("Job '\(id)' completed successfully")

            case .failure(let error):
                let errors = (state.jobs[id]?.consecutiveErrors ?? 0) + 1
                state.jobs[id]?.consecutiveErrors = errors
                state.jobs[id]?.lastError = error.localizedDescription
                log("Job '\(id)' failed (attempt \(errors)): \(error.localizedDescription)")

                if let max = maxRetries, errors >= max {
                    state.jobs[id]?.enabled = false
                    log("Job '\(id)' disabled after \(max) failures")
                }
            }

            persistState()
        }
    }

    // MARK: - State persistence

    private func persistState() {
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: URL(fileURLWithPath: stateFilePath))
        } catch {
            log("Failed to persist cron state: \(error.localizedDescription)")
        }
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [cron] \(message)")
    }
}
