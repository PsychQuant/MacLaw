import Foundation

/// Routes LLM requests to primary provider, falling back on failure.
actor ModelRouter {
    private let primary: LLMProvider?
    private let fallback: LLMProvider?

    init(config: LLMConfig?) {
        self.primary = config?.primary.map { LLMProvider(endpoint: $0) }
        self.fallback = config?.fallback.map { LLMProvider(endpoint: $0) }
    }

    func complete(messages: [LLMProvider.ChatMessage]) async throws -> String {
        // Try primary
        if let primary {
            do {
                return try await primary.complete(messages: messages)
            } catch {
                let model = await primary.model
                log("Primary model (\(model)) failed: \(error.localizedDescription)")
                // Fall through to fallback
            }
        }

        // Try fallback
        if let fallback {
            do {
                return try await fallback.complete(messages: messages)
            } catch {
                let model = await fallback.model
                log("Fallback model (\(model)) also failed: \(error.localizedDescription)")
            }
        }

        throw LLMError.allProvidersFailed
    }

    private func log(_ message: String) {
        let ts = ISO8601DateFormatter().string(from: Date())
        print("[\(ts)] [llm] \(message)")
    }
}
