import Foundation
import Network

/// Polls Telegram getUpdates with automatic reconnection on network changes.
/// Uses NWPathMonitor to detect sleep/wake and connectivity transitions.
actor TelegramPoller {
    private let api: TelegramAPI
    private let onMessage: @Sendable (TGMessage) async -> Void
    private var lastUpdateId: Int?
    private var pollingTask: Task<Void, Never>?
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "maclaw.network-monitor")
    private var currentPath: NWPath.Status = .unsatisfied

    init(api: TelegramAPI, onMessage: @Sendable @escaping (TGMessage) async -> Void) {
        self.api = api
        self.onMessage = onMessage
    }

    func start() async {
        // Clear any stale webhook
        try? await api.deleteWebhook()

        // Start network path monitoring
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            Task {
                await self.handlePathChange(path)
            }
        }
        pathMonitor.start(queue: monitorQueue)

        // Begin polling
        startPollingLoop()
        log("Telegram poller started")
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        pathMonitor.cancel()
        log("Telegram poller stopped")
    }

    // MARK: - Network path changes

    private func handlePathChange(_ path: NWPath) {
        let newStatus = path.status
        let oldStatus = currentPath
        currentPath = newStatus

        if oldStatus != .satisfied && newStatus == .satisfied {
            log("Network restored — restarting poll immediately")
            restartPolling()
        } else if oldStatus == .satisfied && newStatus != .satisfied {
            log("Network lost — pausing poll")
            pollingTask?.cancel()
        }
    }

    private func restartPolling() {
        pollingTask?.cancel()
        startPollingLoop()
    }

    // MARK: - Polling loop

    private func startPollingLoop() {
        pollingTask = Task {
            var backoffMs: UInt64 = 2000

            while !Task.isCancelled {
                do {
                    let offset = await self.lastUpdateId.map { $0 + 1 }
                    let updates = try await self.api.getUpdates(offset: offset, timeout: 30)
                    backoffMs = 2000  // reset on success

                    for update in updates {
                        await self.setLastUpdateId(update.updateId)
                        if let message = update.message {
                            await self.onMessage(message)
                        }
                    }
                } catch is CancellationError {
                    break
                } catch {
                    if !Task.isCancelled {
                        await self.log("Poll error: \(error.localizedDescription), retry in \(backoffMs)ms")
                        try? await Task.sleep(nanoseconds: backoffMs * 1_000_000)
                        backoffMs = min(backoffMs * 2, 30_000)
                    }
                }
            }
        }
    }

    private func setLastUpdateId(_ id: Int) {
        lastUpdateId = id
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [telegram] \(message)")
    }
}
