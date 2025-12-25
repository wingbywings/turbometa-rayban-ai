/*
 * Omni Realtime View
 * Real-time multimodal conversation interface
 */

import SwiftUI

struct OmniRealtimeView: View {
    @StateObject private var viewModel: OmniRealtimeViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self._viewModel = StateObject(wrappedValue: OmniRealtimeViewModel(apiKey: apiKey))
    }

    var body: some View {
        ZStack {
            // Video background from glasses
            if let videoFrame = streamViewModel.currentVideoFrame {
                Image(uiImage: videoFrame)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
                    .opacity(0.3)
            } else {
                Color.black.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // Header
                headerView

                // Conversation history
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

                // Status and controls
                controlsView
            }
        }
        .onAppear {
            viewModel.connect()
            // Update video frames
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if let frame = streamViewModel.currentVideoFrame {
                    viewModel.updateVideoFrame(frame)
                }
            }
        }
        .onDisappear {
            viewModel.disconnect()
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
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
            Text("AI 实时对话")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // Connection status
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineSpacing(2)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Controls

    private var controlsView: some View {
        VStack(spacing: 12) {
            // Speaking indicator
            if viewModel.isSpeaking {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    Text("正在说话...")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green.opacity(0.2))
                .cornerRadius(20)
            }

            // Recording status
            HStack(spacing: 8) {
                if viewModel.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("录音中")
                        .font(.caption)
                        .foregroundColor(.white)
                } else {
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                    Text("未录音")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)

            // Control buttons
            HStack(spacing: 20) {
                // Start/Stop Recording
                Button {
                    if viewModel.isRecording {
                        viewModel.stopRecording()
                    } else {
                        viewModel.startRecording()
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.isRecording ? "mic.fill" : "mic.slash.fill")
                            .font(.title)
                        Text(viewModel.isRecording ? "停止" : "开始")
                            .font(.caption)
                    }
                    .frame(width: 80, height: 80)
                    .background(viewModel.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(!viewModel.isConnected)
            }
            .padding()
        }
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ConversationMessage
    @State private var selectedAttachment: ConversationImageAttachment?

    private var isUser: Bool {
        message.role == .user
    }

    private var bubbleGradient: LinearGradient {
        if isUser {
            return LinearGradient(
                colors: [AppColors.liveAI, AppColors.liveAI.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color.black.opacity(0.75), AppColors.secondary.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.5), Color.white.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var glowColor: Color {
        isUser ? AppColors.liveAI : AppColors.secondary
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer()
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if isUser {
                    Text("YOU")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                } else {
                    Text("AI")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 4)
                }

                if message.imageAttachments.count == 1,
                   let attachment = message.imageAttachments.first {
                    HStack {
                        if isUser {
                            Spacer(minLength: 0)
                        }
                        ConversationImageThumbnail(attachment: attachment)
                            .onTapGesture {
                                selectedAttachment = attachment
                            }
                        if !isUser {
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: 260)
                } else if !message.imageAttachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(message.imageAttachments) { attachment in
                                ConversationImageThumbnail(attachment: attachment)
                                    .onTapGesture {
                                        selectedAttachment = attachment
                                    }
                            }
                        }
                    }
                    .frame(maxWidth: 260, alignment: isUser ? .trailing : .leading)
                }

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

            if message.role == .assistant {
                Spacer()
            }
        }
        .sheet(item: $selectedAttachment) { attachment in
            ConversationImageViewer(attachment: attachment)
        }
    }
}

struct ConversationImageThumbnail: View {
    let attachment: ConversationImageAttachment

    var body: some View {
        if let image = ConversationImageStorage.shared.loadPreviewImage(attachment) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 160, height: 120)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.35))
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(width: 160, height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct ConversationImageViewer: View {
    let attachment: ConversationImageAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let image = ConversationImageStorage.shared.loadOriginalImage(attachment) {
                ZoomableImageView(image: image)
                    .padding(24)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.7))
                    Text("Image unavailable")
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(16)
            }
        }
    }
}

struct ZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    var body: some View {
        let magnification = MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                if scale <= minScale {
                    resetTransform()
                } else {
                    lastScale = scale
                }
            }

        let drag = DragGesture()
            .onChanged { value in
                guard scale > minScale else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > minScale else {
                    resetTransform()
                    return
                }
                lastOffset = offset
            }

        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(drag.simultaneously(with: magnification))
            .animation(.easeInOut(duration: 0.15), value: scale)
    }

    private func resetTransform() {
        scale = minScale
        lastScale = minScale
        offset = .zero
        lastOffset = .zero
    }
}

// MARK: - Preview
// Preview requires real wearables instance
