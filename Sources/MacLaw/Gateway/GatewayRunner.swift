import Foundation

/// Orchestrates all MacLaw services: Telegram + Backend + Cron.
actor GatewayRunner {
    static let currentModel = CurrentModel()
    static let activeBackend = ActiveBackend()
    static let sessionManager = SessionManager()
    static let permissionMode = PermissionMode()
    nonisolated(unsafe) static var configuredAllowedTools: [String]?
    nonisolated(unsafe) static var sharedActivationEngine: ActivationEngine?
    private let config: MacLawConfig
    private var telegramAPI: TelegramAPI?
    private var poller: TelegramPoller?
    private var cronScheduler: CronScheduler?
    private var activationEngine: ActivationEngine?
    private var pipelines: [PipelineConfig] = []

    init(config: MacLawConfig) {
        self.config = config
    }

    func run() async throws {
        log("MacLaw gateway starting...")

        // 0. Resolve backend + load sessions for this backend
        let backend = BackendRegistry.resolve(name: config.backend)
        await GatewayRunner.activeBackend.set(backend)
        await GatewayRunner.sessionManager.loadForBackend(backend.name)
        GatewayRunner.configuredAllowedTools = config.allowedTools
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

        // 3. Start cron scheduler (legacy)
        if let cronJobs = config.cron?.jobs, !cronJobs.isEmpty {
            let cronAPI = api
            cronScheduler = CronScheduler(jobs: cronJobs) { job in
                await GatewayRunner.executeCronJob(job, api: cronAPI)
            }
            await cronScheduler!.start()
        }

        // 4. Start activation engine (new: event, schedule, interval + pipeline)
        let configuredActivations = buildActivations(from: config)
        if !configuredActivations.isEmpty {
            pipelines = config.pipelines ?? []
            let activationAPI = api
            let activationPipelines = pipelines
            activationEngine = ActivationEngine(activations: configuredActivations) { activation, context in
                await GatewayRunner.executeActivation(activation, context: context, pipelines: activationPipelines, api: activationAPI)
            }
            await activationEngine!.start()
            GatewayRunner.sharedActivationEngine = activationEngine
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
        await activationEngine?.stop()
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

        // Check event activations (runs in parallel with normal chat handling)
        if let engine = GatewayRunner.sharedActivationEngine {
            let _ = await engine.handleTelegramMessage(
                chatId: String(chatId),
                senderId: message.from?.id.description ?? "",
                text: text
            )
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
            let isGroup = message.chat.type != "private"
            let existingSession = await GatewayRunner.sessionManager.getSessionId(forChat: chatKey)
            // Group: include sender name so AI knows who's talking
            let prompt = isGroup ? "\(senderName): \(text)" : text
            print("[\(ts)] [gateway] Calling backend (group=\(isGroup), session=\(existingSession ?? "new"))")
            let mode = await GatewayRunner.permissionMode.get()
            let tools: [String]? = mode == "full" ? nil : GatewayRunner.configuredAllowedTools
            let (response, newSessionId, shouldRespond) = try await backend.run(
                prompt: prompt, model: model, sessionId: existingSession, isGroupChat: isGroup,
                allowedTools: tools
            )
            typingTask.cancel()
            print("[\(ts)] [gateway] Backend returned: shouldRespond=\(shouldRespond), hasResponse=\(response != nil), sessionId=\(newSessionId ?? "nil")")
            if let sid = newSessionId ?? existingSession {
                await GatewayRunner.sessionManager.updateSession(chatId: chatKey, sessionId: sid)
            }
            guard shouldRespond, let response, !response.isEmpty else {
                print("[\(ts)] [gateway] Skipping reply (shouldRespond=\(shouldRespond))")
                return
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
            let (response, _, _) = try await backend.run(prompt: job.prompt, model: nil, sessionId: nil, isGroupChat: false, allowedTools: GatewayRunner.configuredAllowedTools)
            let text = response ?? ""

            if let chatIdStr = job.deliverTo, let chatId = Int64(chatIdStr) {
                try await TelegramSender.send(api: api, chatId: chatId, text: "[\(job.name)]\n\n\(text)")
            }

            return .success(text)
        } catch {
            return .failure(error)
        }
    }

    /// Build activation configs, including legacy cron jobs mapped to interval activations.
    private func buildActivations(from config: MacLawConfig) -> [ActivationConfig] {
        var result = config.activations ?? []

        // Map legacy cron jobs to interval activations (backward compatibility)
        if let cronJobs = config.cron?.jobs {
            for job in cronJobs {
                let id = job.id ?? "cron-\(job.name)"
                // Skip if there's already an activation with this ID
                guard !result.contains(where: { $0.id == id }) else { continue }

                let schedule = job.schedule
                if schedule.hasPrefix("every ") {
                    let intervalStr = String(schedule.dropFirst(6))
                    result.append(ActivationConfig(
                        id: id, type: .interval, enabled: true,
                        schedule: nil, interval: intervalStr, event: nil,
                        action: ActionConfig(type: .task, prompt: job.prompt, pipeline: nil)
                    ))
                    log("Mapped legacy cron '\(job.name)' → activation-interval '\(id)'")
                }
                // "at <date>" one-shots stay in legacy CronScheduler for now
            }
        }

        return result
    }

    private static func executeActivation(
        _ activation: ActivationConfig,
        context: ActivationContext,
        pipelines: [PipelineConfig],
        api: TelegramAPI
    ) async -> Result<String, Error> {
        switch activation.action.type {
        case .task:
            // Single task: run prompt through backend
            guard let prompt = activation.action.prompt else {
                return .failure(GatewayError.missingConfig("activation prompt"))
            }
            do {
                let backend = await GatewayRunner.activeBackend.get()
                let (response, _, _) = try await backend.run(
                    prompt: prompt, model: nil, sessionId: nil,
                    isGroupChat: false, allowedTools: GatewayRunner.configuredAllowedTools
                )
                return .success(response ?? "")
            } catch {
                return .failure(error)
            }

        case .pipeline:
            guard let pipelineId = activation.action.pipeline,
                  let pipeline = pipelines.first(where: { $0.id == pipelineId }) else {
                return .failure(PipelineError.pipelineNotFound(id: activation.action.pipeline ?? "nil"))
            }

            let runner = PipelineRunner { prompt in
                do {
                    let backend = await GatewayRunner.activeBackend.get()
                    let (response, _, _) = try await backend.run(
                        prompt: prompt, model: nil, sessionId: nil,
                        isGroupChat: false, allowedTools: GatewayRunner.configuredAllowedTools
                    )
                    return .success(response ?? "")
                } catch {
                    return .failure(error)
                }
            }

            let result = await runner.run(pipeline: pipeline, context: context)
            switch result {
            case .success(let steps):
                let output = steps.last?.output ?? ""
                return .success(output)
            case .failure(let error):
                return .failure(error)
            }
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
