import Foundation

/// Orchestrates all MacLaw services: Telegram, LLM, Cron.
actor GatewayRunner {
    private let config: MacLawConfig
    private var telegramAPI: TelegramAPI?
    private var poller: TelegramPoller?
    private var router: ModelRouter?
    private var cronScheduler: CronScheduler?

    init(config: MacLawConfig) {
        self.config = config
    }

    func run() async throws {
        log("MacLaw gateway starting...")

        // 1. Initialize LLM router
        router = ModelRouter(config: config.llm)
        log("LLM router initialized")

        // 2. Initialize Telegram
        guard let tgConfig = config.telegram else {
            throw GatewayError.missingConfig("telegram")
        }
        let api = TelegramAPI(token: tgConfig.botToken)
        telegramAPI = api

        // 3. Start Telegram poller
        let messageRouter = router!
        let tgAPI = api
        poller = TelegramPoller(api: api) { [weak self] message in
            guard self != nil else { return }
            await GatewayRunner.handleMessage(message, router: messageRouter, api: tgAPI)
        }
        await poller!.start()
        log("Telegram poller started")

        // 4. Start cron scheduler
        if let cronJobs = config.cron?.jobs, !cronJobs.isEmpty {
            let cronRouter = router!
            let cronAPI = api
            cronScheduler = CronScheduler(jobs: cronJobs) { job in
                await GatewayRunner.executeCronJob(job, router: cronRouter, api: cronAPI)
            }
            await cronScheduler!.start()
        }

        log("MacLaw gateway running. Press Ctrl+C to stop.")

        // Keep running until signal
        let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sigSource.setEventHandler {
                continuation.resume()
            }
            sigSource.resume()

            let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
            termSource.setEventHandler {
                continuation.resume()
            }
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

    private static func handleMessage(
        _ message: TGMessage,
        router: ModelRouter,
        api: TelegramAPI
    ) async {
        guard let text = message.text, !text.isEmpty else { return }

        let chatId = message.chat.id
        let senderName = message.from?.displayName ?? "Unknown"
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [gateway] Message from \(senderName) in \(chatId): \(text.prefix(80))")

        // Send typing indicator
        try? await api.sendChatAction(chatId: chatId)

        // Build messages for LLM
        let llmMessages: [LLMProvider.ChatMessage] = [
            .init(role: "user", content: text),
        ]

        do {
            let response = try await router.complete(messages: llmMessages)
            try await TelegramSender.send(api: api, chatId: chatId, text: response)
        } catch {
            let errorMsg = "Sorry, I'm having trouble right now. Please try again later."
            try? await api.sendMessage(chatId: chatId, text: errorMsg)
            print("[\(ts)] [gateway] Error: \(error.localizedDescription)")
        }
    }

    // MARK: - Cron execution

    private static func executeCronJob(
        _ job: CronJobConfig,
        router: ModelRouter,
        api: TelegramAPI
    ) async -> Result<String, Error> {
        let messages: [LLMProvider.ChatMessage] = [
            .init(role: "user", content: job.prompt),
        ]

        do {
            let response = try await router.complete(messages: messages)

            // Deliver to Telegram if configured
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

enum GatewayError: Error, LocalizedError {
    case missingConfig(String)

    var errorDescription: String? {
        switch self {
        case .missingConfig(let section): "Missing config section: \(section)"
        }
    }
}
