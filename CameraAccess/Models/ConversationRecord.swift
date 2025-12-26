/*
 * Conversation Record Model
 * 对话记录数据模型
 */

import Foundation

struct ConversationRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let messages: [ConversationMessage]
    let aiModel: String
    let language: String
    let category: ConversationCategory

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        messages: [ConversationMessage],
        aiModel: String = "qwen3-omni-flash-realtime",
        language: String = "zh-CN",
        category: ConversationCategory = .liveAI
    ) {
        self.id = id
        self.timestamp = timestamp
        self.messages = messages
        self.aiModel = aiModel
        self.language = language
        self.category = category
    }

    // Computed properties
    var title: String {
        if let firstUserMessage = messages.first(where: { $0.role == .user }) {
            let content = firstUserMessage.content
            return content.count > 30 ? String(content.prefix(30)) + "..." : content
        }
        return "AI 对话"
    }

    var summary: String {
        if let lastMessage = messages.last {
            let content = lastMessage.content
            return content.count > 50 ? String(content.prefix(50)) + "..." : content
        }
        return ""
    }

    var messageCount: Int {
        return messages.count
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(timestamp) {
            formatter.dateFormat = "HH:mm"
            return "今天 " + formatter.string(from: timestamp)
        } else if calendar.isDateInYesterday(timestamp) {
            formatter.dateFormat = "HH:mm"
            return "昨天 " + formatter.string(from: timestamp)
        } else if calendar.isDate(timestamp, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE HH:mm"
            return formatter.string(from: timestamp)
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: timestamp)
        }
    }
}

enum ConversationCategory: String, Codable {
    case liveAI
    case liveTranslate
    case liveChat
}

extension ConversationRecord {
    enum CodingKeys: String, CodingKey {
        case id, timestamp, messages, aiModel, language, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        messages = try container.decode([ConversationMessage].self, forKey: .messages)
        aiModel = try container.decode(String.self, forKey: .aiModel)
        language = try container.decode(String.self, forKey: .language)
        category = try container.decodeIfPresent(ConversationCategory.self, forKey: .category) ?? .liveAI
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(messages, forKey: .messages)
        try container.encode(aiModel, forKey: .aiModel)
        try container.encode(language, forKey: .language)
        try container.encode(category, forKey: .category)
    }
}

// Make ConversationMessage Codable
extension ConversationMessage: Codable {
    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, imageAttachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let roleString = try container.decode(String.self, forKey: .role)
        let content = try container.decode(String.self, forKey: .content)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let imageAttachments = try container.decodeIfPresent(
            [ConversationImageAttachment].self,
            forKey: .imageAttachments
        ) ?? []

        self.init(
            id: id,
            role: roleString == "user" ? .user : .assistant,
            content: content,
            timestamp: timestamp,
            imageAttachments: imageAttachments
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role == .user ? "user" : "assistant", forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        if !imageAttachments.isEmpty {
            try container.encode(imageAttachments, forKey: .imageAttachments)
        }
    }
}
