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
