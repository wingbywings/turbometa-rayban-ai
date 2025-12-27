/*
 * Walk Into Movie Model
 * 走进电影 - 输出结构
 */

import Foundation

struct WalkIntoMovieResult: Equatable {
    let headline: String
    let narration: String
    let rawText: String

    var speechText: String {
        let trimmedHeadline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNarration = narration.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedHeadline.isEmpty {
            return rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if trimmedNarration.isEmpty {
            return trimmedHeadline
        }
        return "\(trimmedHeadline)\n\(trimmedNarration)"
    }
}

struct WalkIntoMovieRecord: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let headline: String
    let narration: String
    let rawText: String
    let imageAttachment: ConversationImageAttachment?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        headline: String,
        narration: String,
        rawText: String,
        imageAttachment: ConversationImageAttachment? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.headline = headline
        self.narration = narration
        self.rawText = rawText
        self.imageAttachment = imageAttachment
    }

    var title: String {
        let trimmedHeadline = headline.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHeadline.isEmpty {
            return trimmedHeadline
        }
        let fallback = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? NSLocalizedString("records.movie.title", comment: "Walk Into Movie title") : fallback
    }

    var summary: String {
        let trimmedNarration = narration.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNarration.isEmpty {
            return trimmedNarration
        }
        let fallback = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.count > 80 ? String(fallback.prefix(80)) + "..." : fallback
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
