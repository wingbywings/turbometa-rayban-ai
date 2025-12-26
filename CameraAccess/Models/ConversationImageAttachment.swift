/*
 * Conversation Image Attachment Model
 */

import Foundation

struct ConversationImageAttachment: Identifiable, Codable {
    let id: UUID
    let fileName: String
    let originalFileName: String?

    init(id: UUID = UUID(), fileName: String, originalFileName: String? = nil) {
        self.id = id
        self.fileName = fileName
        self.originalFileName = originalFileName
    }
}
