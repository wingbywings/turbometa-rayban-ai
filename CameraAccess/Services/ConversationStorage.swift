/*
 * Conversation Storage Service
 * 对话记录持久化服务
 */

import Foundation

class ConversationStorage {
    static let shared = ConversationStorage()

    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "savedConversations"
    private let maxConversations = 100 // 最多保存100条对话

    private init() {}

    // MARK: - Save Conversation

    func saveConversation(_ record: ConversationRecord) {
        var conversations = loadAllConversations()

        // Add new conversation at the beginning
        conversations.insert(record, at: 0)

        // Keep only the most recent maxConversations
        if conversations.count > maxConversations {
            let trimmedConversations = conversations.suffix(from: maxConversations)
            conversations = Array(conversations.prefix(maxConversations))
            trimmedConversations.forEach { ConversationImageStorage.shared.deleteImages(in: $0) }
        }

        // Encode and save
        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: conversationsKey)
            print("💾 [Storage] 保存对话成功: \(record.id), 总数: \(conversations.count)")
        } else {
            print("❌ [Storage] 保存对话失败")
        }
    }

    // MARK: - Load Conversations

    func loadAllConversations() -> [ConversationRecord] {
        guard let data = userDefaults.data(forKey: conversationsKey),
              let conversations = try? JSONDecoder().decode([ConversationRecord].self, from: data) else {
            print("📂 [Storage] 无对话记录或解码失败")
            return []
        }

        print("📂 [Storage] 加载对话成功: \(conversations.count) 条")
        return conversations
    }

    func loadConversations(limit: Int = 20, offset: Int = 0) -> [ConversationRecord] {
        let allConversations = loadAllConversations()
        let endIndex = min(offset + limit, allConversations.count)

        guard offset < allConversations.count else {
            return []
        }

        return Array(allConversations[offset..<endIndex])
    }

    // MARK: - Delete Conversation

    func deleteConversation(_ id: UUID) {
        var conversations = loadAllConversations()
        if let record = conversations.first(where: { $0.id == id }) {
            ConversationImageStorage.shared.deleteImages(in: record)
        }
        conversations.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(conversations) {
            userDefaults.set(encoded, forKey: conversationsKey)
            print("🗑️ [Storage] 删除对话成功: \(id)")
        }
    }

    func deleteAllConversations() {
        userDefaults.removeObject(forKey: conversationsKey)
        ConversationImageStorage.shared.deleteAllImages()
        print("🗑️ [Storage] 清空所有对话")
    }

    // MARK: - Get Conversation

    func getConversation(by id: UUID) -> ConversationRecord? {
        return loadAllConversations().first { $0.id == id }
    }
}

// MARK: - Walk Into Movie Storage

class WalkIntoMovieStorage {
    static let shared = WalkIntoMovieStorage()

    private let userDefaults = UserDefaults.standard
    private let recordsKey = "walkIntoMovieRecords"
    private let maxRecords = 100

    private init() {}

    func saveRecord(_ record: WalkIntoMovieRecord) {
        var records = loadAllRecords()
        records.insert(record, at: 0)

        if records.count > maxRecords {
            let trimmedRecords = records.suffix(from: maxRecords)
            records = Array(records.prefix(maxRecords))
            trimmedRecords.forEach { deleteImages(in: $0) }
        }

        if let encoded = try? JSONEncoder().encode(records) {
            userDefaults.set(encoded, forKey: recordsKey)
            print("💾 [Storage] 保存走进电影记录成功: \(record.id), 总数: \(records.count)")
        } else {
            print("❌ [Storage] 保存走进电影记录失败")
        }
    }

    func loadAllRecords() -> [WalkIntoMovieRecord] {
        guard let data = userDefaults.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([WalkIntoMovieRecord].self, from: data) else {
            print("📂 [Storage] 无走进电影记录或解码失败")
            return []
        }

        print("📂 [Storage] 加载走进电影记录成功: \(records.count) 条")
        return records
    }

    func deleteRecord(_ id: UUID) {
        var records = loadAllRecords()
        if let record = records.first(where: { $0.id == id }) {
            deleteImages(in: record)
        }
        records.removeAll { $0.id == id }

        if let encoded = try? JSONEncoder().encode(records) {
            userDefaults.set(encoded, forKey: recordsKey)
            print("🗑️ [Storage] 删除走进电影记录成功: \(id)")
        }
    }

    func deleteAllRecords() {
        let records = loadAllRecords()
        records.forEach { deleteImages(in: $0) }
        userDefaults.removeObject(forKey: recordsKey)
        print("🗑️ [Storage] 清空走进电影记录")
    }

    private func deleteImages(in record: WalkIntoMovieRecord) {
        if let attachment = record.imageAttachment {
            ConversationImageStorage.shared.deleteImages([attachment])
        }
    }
}
