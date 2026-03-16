import Foundation

/// Low-level Telegram Bot API client using URLSession.
/// Handles JSON encoding/decoding and HTTP transport only.
actor TelegramAPI {
    private let token: String
    private let session: URLSession
    private let baseURL: String

    init(token: String) {
        self.token = token
        self.baseURL = "https://api.telegram.org/bot\(token)"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60  // long-polling needs >30s
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - getUpdates (long-polling)

    func getUpdates(offset: Int?, timeout: Int = 30) async throws -> [TGUpdate] {
        let body = TGGetUpdatesRequest(
            offset: offset,
            timeout: timeout,
            allowedUpdates: ["message"]
        )
        let response: TGResponse<[TGUpdate]> = try await post("getUpdates", body: body)
        return response.result ?? []
    }

    // MARK: - sendMessage

    func sendMessage(chatId: Int64, text: String, parseMode: String? = nil) async throws {
        let body = TGSendMessageRequest(chatId: chatId, text: text, parseMode: parseMode)
        let _: TGResponse<TGMessage> = try await post("sendMessage", body: body)
    }

    // MARK: - sendChatAction

    func sendChatAction(chatId: Int64, action: String = "typing") async throws {
        struct Body: Encodable {
            let chatId: Int64
            let action: String
            enum CodingKeys: String, CodingKey {
                case chatId = "chat_id"
                case action
            }
        }
        let _: TGResponse<Bool> = try await post("sendChatAction", body: Body(chatId: chatId, action: action))
    }

    // MARK: - deleteWebhook

    func deleteWebhook() async throws {
        struct Body: Encodable {
            let dropPendingUpdates: Bool
            enum CodingKeys: String, CodingKey {
                case dropPendingUpdates = "drop_pending_updates"
            }
        }
        let _: TGResponse<Bool> = try await post("deleteWebhook", body: Body(dropPendingUpdates: false))
    }

    // MARK: - HTTP transport

    private func post<Body: Encodable, Response: Decodable>(
        _ method: String,
        body: Body
    ) async throws -> Response {
        let url = URL(string: "\(baseURL)/\(method)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, httpResponse) = try await session.data(for: request)

        guard let http = httpResponse as? HTTPURLResponse else {
            throw TelegramError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            throw TelegramError.httpError(http.statusCode, errorBody)
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Response.self, from: data)
        return decoded
    }
}

enum TelegramError: Error, LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case pollingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Invalid HTTP response"
        case .httpError(let code, let body): "Telegram API error \(code): \(body)"
        case .pollingFailed(let reason): "Polling failed: \(reason)"
        }
    }
}
