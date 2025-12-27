/*
 * Omni Realtime ViewModel
 * Manages real-time multimodal conversation with AI
 */

import Foundation
import SwiftUI
import AVFoundation
import UIKit

@MainActor
class OmniRealtimeViewModel: ObservableObject {

    // Published state
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var isSpeaking = false
    @Published var currentTranscript = ""
    @Published var conversationHistory: [ConversationMessage] = []
    @Published var errorMessage: String?
    @Published var showError = false

    // Service
    private var omniService: OmniRealtimeService
    private let apiKey: String
    private let enableImageInput: Bool
    private let qualitySettings: AIQualitySettings
    private let recordCategory: ConversationCategory
    private var recordLanguage: String
    private var isSessionActive = false
    private var shouldReconnectOnForeground = false
    private var shouldRestartRecording = false
    private var isConnecting = false
    private var isAttemptingReconnect = false
    private var notificationTokens: [NSObjectProtocol] = []
    private var shouldIgnoreErrors = false
    private var hasSavedConversation = false

    // Video frame
    private var currentVideoFrame: UIImage?
    private var isImageSendingEnabled = false // 是否已启用图片发送（第一次音频后）
    private var pendingImageAttachments: [ConversationImageAttachment] = []
    private var pendingUserMessageID: UUID?

    init(
        apiKey: String,
        enableImageInput: Bool = true,
        qualitySettings: AIQualitySettings = .shared,
        sessionInstructions: String = OmniRealtimeService.defaultInstructions,
        recordCategory: ConversationCategory = .liveAI,
        recordLanguage: String = "zh-CN"
    ) {
        self.apiKey = apiKey
        self.enableImageInput = enableImageInput
        self.qualitySettings = qualitySettings
        self.recordCategory = recordCategory
        self.recordLanguage = recordLanguage
        self.omniService = OmniRealtimeService(apiKey: apiKey, sessionInstructions: sessionInstructions)
        setupCallbacks()
        registerAppLifecycleObservers()
    }

    // MARK: - Setup

    private func setupCallbacks() {
        omniService.onConnected = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.isConnected = true
                self.isConnecting = false
                self.shouldReconnectOnForeground = false

                if self.shouldRestartRecording {
                    self.shouldRestartRecording = false
                    self.startRecording()
                }
            }
        }

        omniService.onFirstAudioSent = { [weak self] in
            Task { @MainActor in
                guard let self, self.enableImageInput else { return }
                print("✅ [OmniVM] 收到第一次音频发送回调，启用图片发送")
                // 延迟1秒后启用图片发送能力（确保音频已到达）
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isImageSendingEnabled = true
                    print("📸 [OmniVM] 图片发送已启用，等待用户语音触发")
                }
            }
        }

        omniService.onSpeechStarted = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = true

                // 用户语音触发模式：检测到用户开始说话时，发送一帧图片
                if let strongSelf = self,
                   strongSelf.enableImageInput,
                   strongSelf.isImageSendingEnabled,
                   let frame = strongSelf.currentVideoFrame {
                    if !strongSelf.pendingImageAttachments.isEmpty {
                        ConversationImageStorage.shared.deleteImages(strongSelf.pendingImageAttachments)
                    }
                    strongSelf.pendingImageAttachments = []
                    strongSelf.pendingUserMessageID = UUID()
                    strongSelf.sendKeyFrames(from: frame)
                }
            }
        }

        omniService.onSpeechStopped = { [weak self] in
            Task { @MainActor in
                self?.isSpeaking = false
            }
        }

        omniService.onTranscriptDelta = { [weak self] delta in
            Task { @MainActor in
//                print("📝 [OmniVM] AI回复片段: \(delta)")
                self?.currentTranscript += delta
            }
        }

        omniService.onUserTranscript = { [weak self] userText in
            Task { @MainActor in
                guard let self = self else { return }
                print("💬 [OmniVM] 保存用户语音: \(userText)")
                let messageID = self.pendingUserMessageID ?? UUID()
                let attachments = self.pendingImageAttachments
                self.pendingImageAttachments = []
                self.pendingUserMessageID = messageID
                self.conversationHistory.append(
                    ConversationMessage(
                        id: messageID,
                        role: .user,
                        content: userText,
                        imageAttachments: attachments
                    )
                )
                self.scheduleAttachmentFinalization(for: messageID)
            }
        }

        omniService.onTranscriptDone = { [weak self] fullText in
            Task { @MainActor in
                guard let self = self else { return }
                // 使用累积的currentTranscript，因为done事件可能不包含text字段
                let textToSave = fullText.isEmpty ? self.currentTranscript : fullText
                guard !textToSave.isEmpty else {
                    print("⚠️ [OmniVM] AI回复为空，跳过保存")
                    return
                }
                print("💬 [OmniVM] 保存AI回复: \(textToSave)")
                self.conversationHistory.append(
                    ConversationMessage(role: .assistant, content: textToSave)
                )
                self.currentTranscript = ""
            }
        }

        omniService.onAudioDone = { [weak self] in
            Task { @MainActor in
                // Audio playback complete
            }
        }

        omniService.onError = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.isConnecting = false

                guard self.isSessionActive else {
                    return
                }

                let isForeground = UIApplication.shared.applicationState == .active
                if !isForeground {
                    self.shouldReconnectOnForeground = true
                    self.shouldRestartRecording = self.isRecording || self.shouldRestartRecording
                    return
                }

                if self.shouldAttemptReconnect(for: error) {
                    self.shouldReconnectOnForeground = false
                    self.shouldRestartRecording = self.isRecording || self.shouldRestartRecording
                    self.reconnect()
                    return
                }

                if self.shouldIgnoreErrors {
                    return
                }

                self.errorMessage = error
                self.showError = true
            }
        }
    }

    // MARK: - Connection

    func connect() {
        guard !isConnecting else { return }
        guard UIApplication.shared.applicationState == .active else {
            shouldReconnectOnForeground = true
            return
        }
        if !isSessionActive {
            hasSavedConversation = false
            resetConversationState()
        }
        isSessionActive = true
        shouldIgnoreErrors = UIApplication.shared.applicationState != .active
        isConnecting = true
        omniService.connect()
    }

    func disconnect() {
        // Save conversation before disconnecting
        saveConversationIfNeeded()

        shouldIgnoreErrors = true
        shouldRestartRecording = isRecording
        stopRecording()
        omniService.disconnect()
        isConnected = false
        isImageSendingEnabled = false
        isConnecting = false
        isSessionActive = false
        isAttemptingReconnect = false
        if !pendingImageAttachments.isEmpty {
            ConversationImageStorage.shared.deleteImages(pendingImageAttachments)
        }
        pendingImageAttachments = []
        pendingUserMessageID = nil
        shouldReconnectOnForeground = false
        shouldRestartRecording = false
        unregisterAppLifecycleObservers()
    }

    private func saveConversation() {
        // Only save if there's meaningful conversation
        guard !conversationHistory.isEmpty else {
            print("💬 [OmniVM] 无对话内容，跳过保存")
            return
        }

        let record = ConversationRecord(
            messages: conversationHistory,
            aiModel: "qwen3-omni-flash-realtime",
            language: recordLanguage,
            category: recordCategory
        )

        ConversationStorage.shared.saveConversation(record)
        print("💾 [OmniVM] 对话已保存: \(conversationHistory.count) 条消息")
    }

    private func saveConversationIfNeeded() {
        guard !hasSavedConversation else { return }
        hasSavedConversation = true
        saveConversation()
    }

    private func resetConversationState() {
        if !pendingImageAttachments.isEmpty {
            ConversationImageStorage.shared.deleteImages(pendingImageAttachments)
        }
        pendingImageAttachments = []
        pendingUserMessageID = nil
        currentTranscript = ""
        conversationHistory = []
        errorMessage = nil
        showError = false
        isSpeaking = false
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        guard isConnected else {
            print("⚠️ [OmniVM] 未连接，无法开始录音")
            errorMessage = "请先连接服务器"
            showError = true
            return
        }

        print("🎤 [OmniVM] 开始录音（语音触发模式）")
        omniService.startRecording()
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        print("🛑 [OmniVM] 停止录音")
        omniService.stopRecording()
        isRecording = false
    }

    // MARK: - Video Frames

    func updateVideoFrame(_ frame: UIImage) {
        guard enableImageInput else { return }
        currentVideoFrame = frame
    }

    private func sendKeyFrames(from frame: UIImage) {
        let count = max(1, min(qualitySettings.keyFrameCount, 3))
        let maxDimension = qualitySettings.aiImageMaxDimension.rawValue
        let quality = qualitySettings.aiImageQuality

        for index in 0..<count {
            let delay = Double(index) * 0.15
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                let latestFrame = self.currentVideoFrame ?? frame
                if let attachment = ConversationImageStorage.shared.saveAttachment(
                    latestFrame,
                    aiMaxDimension: maxDimension,
                    aiQuality: quality
                ) {
                    self.appendImageAttachment(attachment)
                }
                self.omniService.sendImageAppend(
                    latestFrame,
                    maxDimension: maxDimension,
                    quality: quality
                )
            }
        }
    }

    private func appendImageAttachment(_ attachment: ConversationImageAttachment) {
        if let messageID = pendingUserMessageID,
           let index = conversationHistory.firstIndex(where: { $0.id == messageID }) {
            var message = conversationHistory[index]
            message.imageAttachments.append(attachment)
            conversationHistory[index] = message
        } else {
            pendingImageAttachments.append(attachment)
        }
    }

    private func scheduleAttachmentFinalization(for messageID: UUID) {
        let count = max(1, min(qualitySettings.keyFrameCount, 3))
        let attachmentDelay = Double(count - 1) * 0.15 + 0.5

        DispatchQueue.main.asyncAfter(deadline: .now() + attachmentDelay) { [weak self] in
            guard let self else { return }
            if self.pendingUserMessageID == messageID {
                self.pendingUserMessageID = nil
                self.pendingImageAttachments.removeAll()
            }
        }
    }

    // MARK: - Manual Mode (if needed)

    func sendMessage() {
        omniService.commitAudioBuffer()
    }

    // MARK: - Cleanup

    func dismissError() {
        showError = false
    }

    func updateSessionInstructions(_ instructions: String) {
        omniService.updateSessionInstructions(instructions)
    }

    func updateRecordLanguage(_ language: String) {
        recordLanguage = language
    }

    private func registerAppLifecycleObservers() {
        guard notificationTokens.isEmpty else { return }
        let center = NotificationCenter.default
        let backgroundToken = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidEnterBackground()
        }
        let foregroundToken = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWillEnterForeground()
        }
        notificationTokens = [backgroundToken, foregroundToken]
    }

    private func unregisterAppLifecycleObservers() {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
    }

    private func handleDidEnterBackground() {
        shouldIgnoreErrors = true
        if isConnected || isRecording {
            shouldReconnectOnForeground = true
            shouldRestartRecording = isRecording || shouldRestartRecording
        }
    }

    private func handleWillEnterForeground() {
        shouldIgnoreErrors = false
        guard shouldReconnectOnForeground else { return }
        reconnect()
    }

    private func reconnect() {
        guard !isAttemptingReconnect else { return }
        isAttemptingReconnect = true

        shouldIgnoreErrors = true
        stopRecording()
        omniService.disconnect()
        isConnected = false
        isConnecting = false

        let isForeground = UIApplication.shared.applicationState == .active
        shouldReconnectOnForeground = !isForeground

        guard isForeground else {
            isAttemptingReconnect = false
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            self.shouldIgnoreErrors = false
            self.connect()
            self.isAttemptingReconnect = false
        }
    }

    private func shouldAttemptReconnect(for error: String) -> Bool {
        let lowercased = error.lowercased()
        if lowercased.contains("software caused connection abort")
            || lowercased.contains("connection aborted")
            || lowercased.contains("connection was lost")
            || lowercased.contains("network connection was lost")
            || lowercased.contains("broken pipe") {
            return true
        }

        if error.contains("连接终止")
            || error.contains("连接已终止")
            || error.contains("软件导致连接终止")
            || error.contains("网络连接已断开") {
            return true
        }

        return false
    }

    deinit {
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        Task { @MainActor [weak omniService] in
            omniService?.disconnect()
        }
    }
}

// MARK: - Conversation Message

struct ConversationMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    var imageAttachments: [ConversationImageAttachment]

    enum MessageRole {
        case user
        case assistant
    }

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        imageAttachments: [ConversationImageAttachment] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.imageAttachments = imageAttachments
    }
}
