/*
 * Live Translate View
 * Real-time speech translation (audio-only)
 */

import SwiftUI

struct LiveTranslateView: View {
    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConversation = true
    @AppStorage("liveTranslateTargetLanguage") private var targetLanguage = "zh-CN"

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        let storedLanguage = UserDefaults.standard.string(forKey: "liveTranslateTargetLanguage") ?? "zh-CN"
        self._viewModel = StateObject(
            wrappedValue: OmniRealtimeViewModel(
                apiKey: apiKey,
                enableImageInput: false,
                sessionInstructions: LiveTranslateView.translationInstructions(targetLanguage: storedLanguage),
                recordCategory: .liveTranslate,
                recordLanguage: storedLanguage
            )
        )
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if !streamViewModel.hasActiveDevice {
                deviceNotConnectedView
            } else {
                VStack(spacing: 0) {
                    headerView
                        .padding(.top, 8)

                    if showConversation {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.conversationHistory) { message in
                                        TranslationMessageBubble(
                                            message: message,
                                            sourceLabel: NSLocalizedString("livetranslate.source", comment: "Source label"),
                                            translationLabel: NSLocalizedString("livetranslate.translation", comment: "Translation label")
                                        )
                                        .id(message.id)
                                    }

                                    if !viewModel.currentTranscript.isEmpty {
                                        TranslationMessageBubble(
                                            message: ConversationMessage(
                                                role: .assistant,
                                                content: viewModel.currentTranscript
                                            ),
                                            sourceLabel: NSLocalizedString("livetranslate.source", comment: "Source label"),
                                            translationLabel: NSLocalizedString("livetranslate.translation", comment: "Translation label")
                                        )
                                        .id("current")
                                    }
                                }
                                .padding()
                            }
                            .onChange(of: viewModel.conversationHistory.count) { _ in
                                if let lastMessage = viewModel.conversationHistory.last {
                                    withAnimation {
                                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: viewModel.currentTranscript) { _ in
                                withAnimation {
                                    proxy.scrollTo("current", anchor: .bottom)
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Spacer()
                    }

                    controlsView
                }
            }
        }
        .onAppear {
            guard streamViewModel.hasActiveDevice else {
                print("⚠️ LiveTranslateView: 未连接RayBan Meta眼镜，跳过启动")
                return
            }

            viewModel.updateSessionInstructions(
                Self.translationInstructions(targetLanguage: targetLanguage)
            )
            viewModel.connect()
        }
        .onChange(of: viewModel.isConnected) { isConnected in
            if isConnected && !viewModel.isRecording {
                viewModel.startRecording()
            }
            if !isConnected && viewModel.isRecording {
                viewModel.stopRecording()
            }
        }
        .onChange(of: targetLanguage) { newValue in
            viewModel.updateSessionInstructions(
                Self.translationInstructions(targetLanguage: newValue)
            )
            viewModel.updateRecordLanguage(newValue)
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .alert(NSLocalizedString("error", comment: "Error"), isPresented: $viewModel.showError) {
            Button(NSLocalizedString("ok", comment: "OK")) {
                viewModel.dismissError()
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("livetranslate.title", comment: "Live Translate title"))
                .font(AppTypography.headline)
                .foregroundColor(.white)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showConversation.toggle()
                }
            } label: {
                Image(systemName: showConversation ? "eye.fill" : "eye.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 32, height: 32)
            }

            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(
                    viewModel.isConnected
                        ? NSLocalizedString("livetranslate.connected", comment: "Connected")
                        : NSLocalizedString("livetranslate.connecting", comment: "Connecting")
                )
                .font(AppTypography.caption)
                .foregroundColor(.white)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: AppSpacing.md) {
            languageSelector

            HStack(spacing: AppSpacing.sm) {
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("livetranslate.listening", comment: "Listening"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("livetranslate.stop", comment: "Stopped"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.black.opacity(0.6))
            .cornerRadius(AppCornerRadius.xl)

            Button {
                viewModel.disconnect()
                dismiss()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text(NSLocalizedString("livetranslate.stop", comment: "Stop"))
                        .font(AppTypography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .padding(.bottom, AppSpacing.lg)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var languageSelector: some View {
        HStack(spacing: AppSpacing.sm) {
            languageButton(
                title: NSLocalizedString("livetranslate.language.chinese", comment: "Chinese"),
                code: "zh-CN"
            )
            languageButton(
                title: NSLocalizedString("livetranslate.language.english", comment: "English"),
                code: "en-US"
            )
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.black.opacity(0.6))
        .cornerRadius(AppCornerRadius.xl)
    }

    private func languageButton(title: String, code: String) -> some View {
        let isSelected = targetLanguage == code

        return Button {
            targetLanguage = code
        } label: {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(isSelected ? AppColors.translate : Color.white.opacity(0.08))
                .cornerRadius(AppCornerRadius.lg)
        }
    }

    // MARK: - Device Not Connected View

    private var deviceNotConnectedView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.translate.opacity(0.6))

                Text(NSLocalizedString("livetranslate.device.notconnected.title", comment: "Device not connected"))
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text(NSLocalizedString("livetranslate.device.notconnected.message", comment: "Connection message"))
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "chevron.left")
                    Text(NSLocalizedString("livetranslate.device.backtohome", comment: "Back to home"))
                        .font(AppTypography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primary)
                .foregroundColor(.white)
                .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }

    private static func translationInstructions(targetLanguage: String) -> String {
        let targetLabel = targetLanguage == "en-US" ? "English" : "Simplified Chinese"
        return """
        You are a real-time translation assistant. You will hear the other person's speech from the user's microphone.
        Translate each sentence into \(targetLabel) as it is spoken.

        Rules:
        1) Output only the translation. No explanations or extra responses.
        2) If the speaker is already using \(targetLabel), output the original text as-is.
        3) Keep it concise and natural; split into short sentences if needed.
        """
    }
}

// MARK: - Translation Message Bubble

struct TranslationMessageBubble: View {
    let message: ConversationMessage
    let sourceLabel: String
    let translationLabel: String

    private var isSource: Bool {
        message.role == .user
    }

    private var bubbleGradient: LinearGradient {
        if isSource {
            return LinearGradient(
                colors: [Color.black.opacity(0.75), Color.black.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [AppColors.translate, AppColors.translate.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.4), Color.white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var labelText: String {
        isSource ? sourceLabel : translationLabel
    }

    private var glowColor: Color {
        isSource ? AppColors.translate.opacity(0.6) : AppColors.translate
    }

    var body: some View {
        HStack {
            if isSource {
                Spacer()
            }

            VStack(alignment: isSource ? .trailing : .leading, spacing: 6) {
                Text(labelText)
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 4)

                Text(message.content)
                    .font(AppTypography.body)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(bubbleGradient)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(borderGradient, lineWidth: 1)
                    )
                    .shadow(color: glowColor.opacity(0.35), radius: 10, x: 0, y: 0)

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 4)
            }

            if !isSource {
                Spacer()
            }
        }
    }
}
