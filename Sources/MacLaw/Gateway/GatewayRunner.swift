import Foundation

/// Orchestrates all MacLaw services: Telegram + Backend CLI + Cron.
actor GatewayRunner {
    static let currentModel = CurrentModel()
    static let activeBackend = ActiveBackend()
    static let sessionManager = SessionManager()
    private let config: MacLawConfig
    private var telegramAPI: TelegramAPI?
    private var poller: TelegramPoller?
    private var cronScheduler: CronScheduler?

    init(config: MacLawConfig) {
        self.config = config
    }

    func run() async throws {
        log("MacLaw gateway starting...")

        // 0. Resolve backend
        let backend = BackendRegistry.resolve(name: config.backend)
        await GatewayRunner.activeBackend.set(backend)
        log("Backend: \(backend.name)")
        if let model = backend.readDefaultModel() {
            log("Model: \(model)")
        }

        // 1. Initialize Telegram
        guard let tgConfig = config.telegram else {
            throw GatewayError.missingConfig("telegram")
        }
        let api = TelegramAPI(token: tgConfig.botToken)
        telegramAPI = api

        // 2. Start Telegram poller
        let tgAPI = api
        let tgConf = tgConfig
        poller = TelegramPoller(api: api) { message in
            await GatewayRunner.handleMessage(message, api: tgAPI, tgConfig: tgConf)
        }
        await poller!.start()
        log("Telegram poller started")

        // 3. Start cron scheduler
        if let cronJobs = config.cron?.jobs, !cronJobs.isEmpty {
            let cronAPI = api
            cronScheduler = CronScheduler(jobs: cronJobs) { job in
                await GatewayRunner.executeCronJob(job, api: cronAPI)
            }
            await cronScheduler!.start()
        }

        log("MacLaw gateway running. Press Ctrl+C to stop.")

        let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sigSource.setEventHandler { continuation.resume() }
            sigSource.resume()
            let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
            termSource.setEventHandler { continuation.resume() }
            termSource.resume()
        }

        sigSource.cancel()
        await stop()
    }

    func stop() async {
        await poller?.stop()
        await cronScheduler?.stop()
        log("Gateway stopped")
    }

    // MARK: - Message handling

    private static func handleMessage(_ message: TGMessage, api: TelegramAPI, tgConfig: TelegramConfig) async {
        guard let text = message.text, !text.isEmpty else { return }

        let chatId = message.chat.id
        let senderName = message.from?.displayName ?? "Unknown"
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [gateway] Message from \(senderName) (\(message.from?.id.description ?? "?")) in \(chatId): \(text.prefix(80))")

        switch AccessControl.check(message: message, config: tgConfig) {
        case .denied(let reason):
            print("[\(ts)] [gateway] Access denied: \(reason)")
            try? await api.sendMessage(chatId: chatId, text: "Access denied: \(reason)")
            return
        case .ignored:
            return
        case .allowed:
            break
        }

        if text.hasPrefix("/") {
            if let response = await TelegramCommandHandler.handle(command: text, message: message, api: api) {
                try? await api.sendMessage(chatId: chatId, text: response)
                return
            }
        }

        // Keep sending "typing..." every 4s until codex responds
        let typingTask = Task {
            while !Task.isCancelled {
                try? await api.sendChatAction(chatId: chatId)
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }

        do {
            let backend = await GatewayRunner.activeBackend.get()
            let model = await GatewayRunner.currentModel.get()
            let chatKey = String(chatId)
            let existingSession = await GatewayRunner.sessionManager.getSessionId(forChat: chatKey)
            let (response, newSessionId) = try await backend.run(prompt: text, model: model, sessionId: existingSession)
            typingTask.cancel()
            if let sid = newSessionId ?? existingSession {
                await GatewayRunner.sessionManager.updateSession(chatId: chatKey, sessionId: sid)
            }
            try await TelegramSender.send(api: api, chatId: chatId, text: response)
        } catch {
            typingTask.cancel()
            let errorMsg = "Sorry, I'm having trouble right now. Please try again later."
            try? await api.sendMessage(chatId: chatId, text: errorMsg)
            print("[\(ts)] [gateway] Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Cron execution

    private static func executeCronJob(_ job: CronJobConfig, api: TelegramAPI) async -> Result<String, Error> {
        do {
            let backend = await GatewayRunner.activeBackend.get()
            let (response, _) = try await backend.run(prompt: job.prompt, model: nil, sessionId: nil)

            if let chatIdStr = job.deliverTo, let chatId = Int64(chatIdStr) {
                try await TelegramSender.send(api: api, chatId: chatId, text: "[\(job.name)]\n\n\(response)")
            }

            return .success(response)
        } catch {
            return .failure(error)
        }
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [gateway] \(message)")
    }
}

/// Thread-safe active backend reference.
actor ActiveBackend {
    private var backend: Backend = CodexBackend()
    func get() -> Backend { backend }
    func set(_ b: Backend) { backend = b }
}

enum GatewayError: Error, LocalizedError {
    case missingConfig(String)
    var errorDescription: String? {
        switch self {
        case .missingConfig(let section): "Missing config section: \(section)"
        }
    }
}
