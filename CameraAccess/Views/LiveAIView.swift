/*
 * Live AI View
 * 自动启动的实时 AI 对话界面
 */

import SwiftUI

struct LiveAIView: View {
    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConversation = true // 控制对话内容显示/隐藏

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self._viewModel = StateObject(wrappedValue: OmniRealtimeViewModel(apiKey: apiKey))
    }

    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()

            // 未连接设备提醒
            if !streamViewModel.hasActiveDevice {
                deviceNotConnectedView
            } else {
                // Video feed (full opacity, no white mask)
                if let videoFrame = streamViewModel.currentVideoFrame {
                    GeometryReader { geometry in
                        Image(uiImage: videoFrame)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                    .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                // Header (紧贴状态栏)
                headerView
                    .padding(.top, 8) // 状态栏下方一点点

                // Conversation history (可隐藏)
                if showConversation {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.conversationHistory) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

                                // Current AI response (streaming)
                                if !viewModel.currentTranscript.isEmpty {
                                    MessageBubble(
                                        message: ConversationMessage(
                                            role: .assistant,
                                            content: viewModel.currentTranscript
                                        )
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

                // Status and stop button
                controlsView
                }
            }

            if streamViewModel.hasActiveDevice,
               viewModel.showError,
               let message = viewModel.errorMessage {
                errorOverlay(message)
            }
        }
        .onAppear {
            // 只有设备连接时才启动功能
            guard streamViewModel.hasActiveDevice else {
                print("⚠️ LiveAIView: 未连接RayBan Meta眼镜，跳过启动")
                return
            }

            // 启动视频流
            Task(priority: .utility) {
                print("🎥 LiveAIView: 启动视频流")
                await streamViewModel.handleStartStreaming(for: .liveAI)
            }

            // 自动连接并开始录音
            viewModel.connect()

            // 更新视频帧
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let frame = streamViewModel.currentVideoFrame {
                    viewModel.updateVideoFrame(frame)
                }
            }

            // 延迟启动录音，等待连接完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if viewModel.isConnected {
                    viewModel.startRecording()
                }
            }
        }
        .onChange(of: viewModel.isConnected) { isConnected in
            if isConnected && !viewModel.isRecording {
                viewModel.startRecording()
            }
            if !isConnected && viewModel.isRecording {
                viewModel.stopRecording()
            }
        }
        .onDisappear {
            // 停止 AI 对话和视频流
            print("🎥 LiveAIView: 停止 AI 对话和视频流")
            viewModel.disconnect()
            Task {
                if streamViewModel.streamingStatus != .stopped {
                    await streamViewModel.stopSession()
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("liveai.title", comment: "Live AI title"))
                .font(AppTypography.headline)
                .foregroundColor(.white)

            Spacer()

            // Hide/show conversation button
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

            // Connection status
            HStack(spacing: AppSpacing.xs) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnected ? NSLocalizedString("liveai.connected", comment: "Connected") : NSLocalizedString("liveai.connecting", comment: "Connecting"))
                    .font(AppTypography.caption)
                    .foregroundColor(.white)
            }

            // Speaking indicator
            if viewModel.isSpeaking {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("liveai.speaking", comment: "AI speaking"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: AppSpacing.md) {
            // Recording status
            HStack(spacing: AppSpacing.sm) {
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("liveai.listening", comment: "Listening"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("liveai.stop", comment: "Stopped"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.black.opacity(0.6))
            .cornerRadius(AppCornerRadius.xl)

            // Stop button (only button)
            Button {
                viewModel.disconnect()
                dismiss()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                    Text(NSLocalizedString("liveai.stop", comment: "Stop"))
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

    private func errorOverlay(_ message: String) -> some View {
        VStack {
            Spacer()

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(NSLocalizedString("realtime.error.title", comment: "Connection error title"))
                    .font(AppTypography.headline)
                    .foregroundColor(.white)

                Text(message)
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                HStack(spacing: AppSpacing.sm) {
                    Button {
                        viewModel.dismissError()
                        viewModel.connect()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "arrow.clockwise")
                            Text(NSLocalizedString("realtime.error.retry", comment: "Reconnect"))
                        }
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(AppColors.liveAI)
                        .cornerRadius(AppCornerRadius.lg)
                    }

                    Button {
                        viewModel.dismissError()
                        viewModel.disconnect()
                        dismiss()
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "xmark")
                            Text(NSLocalizedString("realtime.error.exit", comment: "Exit"))
                        }
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(AppCornerRadius.lg)
                    }
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.7))
            .cornerRadius(AppCornerRadius.lg)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Device Not Connected View

    private var deviceNotConnectedView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 80))
                    .foregroundColor(AppColors.liveAI.opacity(0.6))

                Text(NSLocalizedString("liveai.device.notconnected.title", comment: "Device not connected"))
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text(NSLocalizedString("liveai.device.notconnected.message", comment: "Connection message"))
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            // Back button
            Button {
                dismiss()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "chevron.left")
                    Text(NSLocalizedString("liveai.device.backtohome", comment: "Back to home"))
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
}
