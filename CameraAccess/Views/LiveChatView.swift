/*
 * Live Chat View
 * Audio-only real-time AI conversation
 */

import SwiftUI

struct LiveChatView: View {
    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showConversation = true

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self._viewModel = StateObject(
            wrappedValue: OmniRealtimeViewModel(apiKey: apiKey, enableImageInput: false)
        )
    }

    var body: some View {
        ZStack {
            liveChatBackground

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
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

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
            guard streamViewModel.hasActiveDevice else {
                print("⚠️ LiveChatView: 未连接RayBan Meta眼镜，跳过启动")
                return
            }

            viewModel.connect()
            attemptStartRecordingIfReady()
        }
        .onChange(of: viewModel.isConnected) { isConnected in
            if !isConnected && viewModel.isRecording {
                viewModel.stopRecording()
            }
            attemptStartRecordingIfReady()
        }
        .onDisappear {
            viewModel.disconnect()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("livechat.title", comment: "Live Chat title"))
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
                        ? NSLocalizedString("livechat.connected", comment: "Connected")
                        : NSLocalizedString("livechat.connecting", comment: "Connecting")
                )
                .font(AppTypography.caption)
                .foregroundColor(.white)
            }

            if viewModel.isSpeaking {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("livechat.speaking", comment: "AI speaking"))
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
            HStack(spacing: AppSpacing.sm) {
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("livechat.listening", comment: "Listening"))
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("livechat.stop", comment: "Stopped"))
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
                    Text(NSLocalizedString("livechat.stop", comment: "Stop"))
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
                        .background(AppColors.translate)
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
                    .foregroundColor(AppColors.translate.opacity(0.6))

                Text(NSLocalizedString("livechat.device.notconnected.title", comment: "Device not connected"))
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.textPrimary)

                Text(NSLocalizedString("livechat.device.notconnected.message", comment: "Connection message"))
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
                    Text(NSLocalizedString("livechat.device.backtohome", comment: "Back to home"))
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

    private var liveChatBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    AppColors.translate.opacity(0.22),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let size = proxy.size

                Circle()
                    .fill(AppColors.translate.opacity(0.18))
                    .frame(width: size.width * 0.85, height: size.width * 0.85)
                    .position(x: size.width * 0.8, y: size.height * 0.2)
                    .blur(radius: 48)

                Circle()
                    .fill(AppColors.translate.opacity(0.14))
                    .frame(width: size.width * 0.6, height: size.width * 0.6)
                    .position(x: size.width * 0.15, y: size.height * 0.85)
                    .blur(radius: 56)
            }
            .ignoresSafeArea()
        }
    }

    private var isReadyToStartRecording: Bool {
        viewModel.isConnected
    }

    private func attemptStartRecordingIfReady() {
        guard isReadyToStartRecording else { return }
        viewModel.startRecording()
    }
}
