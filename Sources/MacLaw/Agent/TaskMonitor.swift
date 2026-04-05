import Foundation

/// Monitors spawned backend tasks for completion and liveness.
/// Replaces synchronous blocking with background polling.
actor TaskMonitor {
    private var tasks: [String: BackendTask] = [:]
    private var idleCounters: [String: Int] = [:]
    private var monitorTask: Task<Void, Never>?
    private let onComplete: @Sendable (BackendTask, String?) async -> Void
    private let onStuck: @Sendable (BackendTask) async -> Void
    private let idleThresholdMinutes: Int

    /// - Parameters:
    ///   - idleThresholdMinutes: Minutes of zero CPU before a task is considered stuck (default: 10)
    ///   - onComplete: Called when a task finishes. Second param is the output text.
    ///   - onStuck: Called when a task is detected as stuck and killed.
    init(
        idleThresholdMinutes: Int = 10,
        onComplete: @Sendable @escaping (BackendTask, String?) async -> Void,
        onStuck: @Sendable @escaping (BackendTask) async -> Void
    ) {
        self.idleThresholdMinutes = idleThresholdMinutes
        self.onComplete = onComplete
        self.onStuck = onStuck
    }

    /// Add a task to be monitored.
    func track(_ task: BackendTask) {
        tasks[task.id] = task
        idleCounters[task.id] = 0
        log("Tracking task \(task.id) (PID \(task.pid)) for chat \(task.chatId)")
        ensureMonitorRunning()
    }

    /// Number of currently tracked tasks.
    var activeCount: Int { tasks.count }

    /// Stop all monitoring.
    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    // MARK: - Monitor loop

    private func ensureMonitorRunning() {
        guard monitorTask == nil else { return }
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                guard let self else { break }
                await self.checkTasks()
                let count = await self.activeCount
                if count == 0 {
                    await self.stopMonitor()
                    break
                }
            }
        }
    }

    private func stopMonitor() {
        monitorTask = nil
    }

    private func checkTasks() async {
        for (id, task) in tasks {
            if !task.isRunning {
                // Process finished — read output and notify
                let output = task.readOutput()
                log("Task \(id) (PID \(task.pid)) finished, output: \(output?.prefix(100).description ?? "nil")")
                tasks.removeValue(forKey: id)
                idleCounters.removeValue(forKey: id)
                await onComplete(task, output)
                task.cleanup()
                continue
            }

            // Process still running — check liveness
            let cpu = task.cpuUsage
            if cpu < 0.1 {
                idleCounters[id, default: 0] += 1
                let idleMinutes = idleCounters[id, default: 0]
                if idleMinutes >= idleThresholdMinutes {
                    log("Task \(id) (PID \(task.pid)) stuck: CPU=0 for \(idleMinutes) minutes. Killing.")
                    task.terminate()
                    tasks.removeValue(forKey: id)
                    idleCounters.removeValue(forKey: id)
                    await onStuck(task)
                    task.cleanup()
                }
            } else {
                // Alive — reset counter
                idleCounters[id] = 0
            }
        }
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [task-monitor] \(message)")
    }
}
