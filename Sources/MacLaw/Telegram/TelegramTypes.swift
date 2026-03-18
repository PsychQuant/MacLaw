import Foundation

// MARK: - Telegram Bot API Types (subset for MVP)

struct TGUpdate: Decodable {
    let updateId: Int
    let message: TGMessage?

    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
    }
}

struct TGMessage: Decodable {
    let messageId: Int
    let from: TGUser?
    let chat: TGChat
    let date: Int
    let text: String?
    let replyToMessage: TGReplyMessage?

    enum CodingKeys: String, CodingKey {
        case messageId = "message_id"
        case from, chat, date, text
        case replyToMessage = "reply_to_message"
    }
}

/// Lightweight version to avoid recursive decoding
struct TGReplyMessage: Decodable {
    let from: TGUser?
}

struct TGUser: Decodable {
    let id: Int64
    let firstName: String
    let lastName: String?
    let username: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case username
    }

    var displayName: String {
        if let last = lastName {
            return "\(firstName) \(last)"
        }
        return firstName
    }
}

struct TGChat: Decodable {
    let id: Int64
    let type: String  // "private", "group", "supergroup"
    let title: String?
}

struct TGResponse<T: Decodable>: Decodable {
    let ok: Bool
    let result: T?
    let description: String?
}

// MARK: - Request types

struct TGSendMessageRequest: Encodable {
    let chatId: Int64
    let text: String
    let parseMode: String?

    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case text
        case parseMode = "parse_mode"
    }
}

struct TGGetUpdatesRequest: Encodable {
    let offset: Int?
    let timeout: Int
    let allowedUpdates: [String]?

    enum CodingKeys: String, CodingKey {
        case offset, timeout
        case allowedUpdates = "allowed_updates"
    }
}
