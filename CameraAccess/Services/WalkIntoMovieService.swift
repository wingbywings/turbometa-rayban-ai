/*
 * Walk Into Movie Service
 * 走进电影 - 氛围识别服务
 */

import Foundation

struct WalkIntoMovieService {
    static let prompt2 = """
你是一位擅长“走进电影”的氛围识别器。根据图片里的环境、光线、场景与情绪判断它像哪部电影 / 剧集 / 游戏。

请只输出两行文本：
第一行：一句话点题（示例：你现在像在《迷失东京》）
第二行：氛围旁白（30-80字，描述图片的画面，并结合电影让描述具有画面感）

要求：
- 使用中文
- 不要输出编号、引号、Markdown 或解释
"""
    
    static let prompt = """
你是一个“现实世界电影感知器”。
你的任务不是描述图片，而是判断：
这张图片中的现实场景，最像哪一类电影、剧集或游戏的一个片段。

不要客观分析，不要解释推理过程，
不要使用“这张图片显示”“看起来像”之类的描述性语言。

你要像一位冷静而富有文学感的电影旁白，
为正在经历这一刻的人，赋予叙事意义。

⸻

📥 输入
    •    一张来自第一人称视角的现实环境图片
（街道 / 室内 / 城市 / 旅行 / 日常场景均可）

⸻

📤 输出格式（严格遵守）

**使用中文**
请只输出两行文本：
第一行：一句话点题（示例：你现在像在《迷失东京》，这不是目的地，只是故事暂时停留的地方。）
一句极短的电影式旁白，像影评中的空镜解说
必须克制、含蓄，不煽情、不解释

第二行：氛围旁白（30-80字，具有画面感）
1–2 句话，像电影里低声出现的旁白
语气平静，确认这一刻的情绪，而不是讲故事
示例：
有些时刻不会被记住，
但它们构成了你走到这里的全部理由。

要求：
- 使用中文
- 不要输出编号、引号、Markdown 或解释

🎯 总体风格要求
    •    像电影，不像社交媒体
    •    像旁白，不像文案
    •    像理解，不像解读
"""

    static let userPrompt = "请根据输入的照片画面输出走进电影的结果"

    static func parseResult(from text: String) -> WalkIntoMovieResult {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var headline = ""
        var narration = ""

        if !lines.isEmpty {
            headline = sanitizeLine(lines[0], prefixes: [
                "一句话：", "一句话:", "一句话—", "一句话 -", "标题：", "标题:"
            ])
        }

        if lines.count >= 2 {
            let remainingLines = lines[1...]
            let merged = remainingLines.joined(separator: " ")
            narration = sanitizeLine(merged, prefixes: [
                "氛围旁白：", "氛围旁白:", "旁白：", "旁白:", "氛围：", "氛围:"
            ])
        }

        if headline.isEmpty {
            headline = cleaned
        }

        return WalkIntoMovieResult(headline: headline, narration: narration, rawText: cleaned)
    }

    private static func sanitizeLine(_ line: String, prefixes: [String]) -> String {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        text = stripNumberPrefix(from: text)

        for prefix in prefixes {
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stripNumberPrefix(from text: String) -> String {
        let pattern = #"^\d+[\.\)、:\-\s]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }
}
