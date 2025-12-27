/*
 * Walk Into Movie View
 * 走进电影体验界面
 */

import SwiftUI

struct WalkIntoMovieView: View {
    @StateObject private var viewModel: WalkIntoMovieViewModel
    @ObservedObject var streamViewModel: StreamSessionViewModel
    @Environment(\.dismiss) private var dismiss

    init(streamViewModel: StreamSessionViewModel, apiKey: String) {
        self.streamViewModel = streamViewModel
        self._viewModel = StateObject(wrappedValue: WalkIntoMovieViewModel(apiKey: apiKey))
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if !streamViewModel.hasActiveDevice {
                deviceNotConnectedView
            } else {
                videoFeed

                VStack(spacing: 0) {
                    headerView
                        .padding(.top, 8)

                    Spacer()

                    resultPanel
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                }
            }
        }
        .onAppear {
            guard streamViewModel.hasActiveDevice else { return }

            Task(priority: .utility) {
                await streamViewModel.handleStartStreaming(for: .walkIntoMovie)
                viewModel.startExperience(
                    frameProvider: { streamViewModel.currentVideoFrame },
                    streamReady: {
                        streamViewModel.streamingStatus == .streaming
                            && streamViewModel.hasReceivedFirstFrame
                            && streamViewModel.currentVideoFrame != nil
                    }
                )
            }
        }
        .onDisappear {
            viewModel.stop()
            Task {
                if streamViewModel.streamingStatus != .stopped {
                    await streamViewModel.stopSession()
                }
            }
        }
    }

    private var videoFeed: some View {
        Group {
            if let videoFrame = streamViewModel.currentVideoFrame {
                GeometryReader { geometry in
                    Image(uiImage: videoFrame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .foregroundColor(.white)
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text(NSLocalizedString("movie.title", comment: "Walk Into Movie title"))
                .font(AppTypography.headline)
                .foregroundColor(.white)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(AppSpacing.md)
        .background(Color.black.opacity(0.7))
    }

    @ViewBuilder
    private var resultPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if viewModel.isAnalyzing {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(NSLocalizedString("movie.analyzing", comment: "Analyzing"))
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white)
                }
            } else if let error = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(NSLocalizedString("movie.error.title", comment: "Error title"))
                        .font(AppTypography.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(AppTypography.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                retryButton
            } else if let result = viewModel.result {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(result.headline)
                        .font(AppTypography.title2)
                        .foregroundColor(.white)

                    if !result.narration.isEmpty {
                        Text(result.narration)
                            .font(AppTypography.body)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                retryButton
            } else {
                Text(NSLocalizedString("movie.ready", comment: "Preparing"))
                    .font(AppTypography.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.7))
        .cornerRadius(AppCornerRadius.lg)
    }

    private var retryButton: some View {
        Button {
            viewModel.retry(
                frameProvider: { streamViewModel.currentVideoFrame },
                streamReady: {
                    streamViewModel.streamingStatus == .streaming
                        && streamViewModel.hasReceivedFirstFrame
                        && streamViewModel.currentVideoFrame != nil
                }
            )
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "arrow.clockwise")
                Text(NSLocalizedString("movie.retry", comment: "Retry"))
            }
            .font(AppTypography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.walkIntoMovie)
            .cornerRadius(AppCornerRadius.lg)
        }
        .disabled(viewModel.isAnalyzing)
    }

    private var deviceNotConnectedView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            VStack(spacing: AppSpacing.lg) {
                Image(systemName: "eyeglasses")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.6))

                Text(NSLocalizedString("movie.device.notconnected.title", comment: "Device not connected title"))
                    .font(AppTypography.title2)
                    .foregroundColor(.white)

                Text(NSLocalizedString("movie.device.notconnected.message", comment: "Device not connected message"))
                    .font(AppTypography.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "chevron.left")
                    Text(NSLocalizedString("movie.device.backtohome", comment: "Back to home"))
                        .font(AppTypography.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(.white)
                .foregroundColor(.black)
                .cornerRadius(AppCornerRadius.lg)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }
}
