import Foundation

/// OpenAI-compatible chat completion client.
actor LLMProvider {
    let baseUrl: String
    let apiKey: String?
    let model: String
    let reasoningEffort: String?
    private let session = URLSession.shared

    init(endpoint: ModelEndpoint) {
        self.baseUrl = endpoint.baseUrl
        self.apiKey = endpoint.apiKey
        self.model = endpoint.model
        self.reasoningEffort = endpoint.reasoningEffort
    }

    struct ChatMessage: Codable, Sendable {
        let role: String
        let content: String
    }

    func complete(messages: [ChatMessage]) async throws -> String {
        let url = URL(string: "\(baseUrl)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        if let effort = reasoningEffort {
            body["reasoning_effort"] = effort
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await session.data(for: request)

        guard let http = httpResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (httpResponse as? HTTPURLResponse)?.statusCode ?? 0
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw LLMError.apiError(code, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.parseError
        }

        return content
    }
}

enum LLMError: Error, LocalizedError {
    case apiError(Int, String)
    case parseError
    case allProvidersFailed

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let body): "LLM API error \(code): \(body)"
        case .parseError: "Failed to parse LLM response"
        case .allProvidersFailed: "All LLM providers failed"
        }
    }
}
