/*
 * Walk Into Movie ViewModel
 * 走进电影 - 识别与语音输出
 */

import Foundation
import SwiftUI
import UIKit

@MainActor
final class WalkIntoMovieViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var result: WalkIntoMovieResult?
    @Published var errorMessage: String?

    private let omniService: OmniRealtimeService
    private let qualitySettings: AIQualitySettings
    private var analysisTask: Task<Void, Never>?
    private var isConnected = false
    private var currentTranscript = ""

    init(apiKey: String, qualitySettings: AIQualitySettings = .shared) {
        self.qualitySettings = qualitySettings
        self.omniService = OmniRealtimeService(
            apiKey: apiKey,
            sessionInstructions: WalkIntoMovieService.prompt
        )
        setupCallbacks()
    }

    func startExperience(
        frameProvider: @escaping () -> UIImage?,
        streamReady: @escaping () -> Bool
    ) {
        analysisTask?.cancel()
        analysisTask = Task { @MainActor [weak self] in
            await self?.captureAndAnalyze(
                frameProvider: frameProvider,
                streamReady: streamReady
            )
        }
    }

    func retry(
        frameProvider: @escaping () -> UIImage?,
        streamReady: @escaping () -> Bool
    ) {
        startExperience(frameProvider: frameProvider, streamReady: streamReady)
    }

    func stop() {
        analysisTask?.cancel()
        omniService.disconnect()
        isConnected = false
    }

    private func setupCallbacks() {
        omniService.onConnected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isConnected = true
            }
        }

        omniService.onTranscriptDelta = { [weak self] delta in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTranscript += delta
                self.result = WalkIntoMovieService.parseResult(from: self.currentTranscript)
            }
        }

        omniService.onTranscriptDone = { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let finalText = text.isEmpty ? self.currentTranscript : text
                self.currentTranscript = finalText
                self.result = WalkIntoMovieService.parseResult(from: finalText)
                self.isAnalyzing = false
            }
        }

        omniService.onAudioDone = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isAnalyzing, self.currentTranscript.isEmpty {
                    self.isAnalyzing = false
                }
            }
        }

        omniService.onError = { [weak self] message in
            Task { @MainActor [weak self] in
                self?.errorMessage = message
                self?.isAnalyzing = false
            }
        }
    }

    private func captureAndAnalyze(
        frameProvider: @escaping () -> UIImage?,
        streamReady: @escaping () -> Bool
    ) async {
        isAnalyzing = true
        errorMessage = nil
        result = nil
        currentTranscript = ""

        omniService.disconnect()
        isConnected = false
        omniService.connect()

        let streamReadyOk = await waitForStreamReady(streamReady)
        guard streamReadyOk else {
            errorMessage = NSLocalizedString("movie.error.nostream", comment: "Stream not ready")
            isAnalyzing = false
            return
        }

        let connected = await waitForConnection()
        guard connected else {
            errorMessage = NSLocalizedString("error.network", comment: "Network error")
            isAnalyzing = false
            return
        }

        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            isAnalyzing = false
            return
        }

        guard !Task.isCancelled else {
            isAnalyzing = false
            return
        }

        guard let frame = await waitForFrame(frameProvider) else {
            errorMessage = NSLocalizedString("movie.error.noframe", comment: "No frame")
            isAnalyzing = false
            return
        }

        let maxDimension = qualitySettings.aiImageMaxDimension.rawValue
        let quality = qualitySettings.aiImageQuality
        omniService.sendUserMessage(
            text: WalkIntoMovieService.userPrompt,
            image: frame,
            maxDimension: maxDimension,
            quality: quality
        )
        omniService.requestResponse()
    }

    private func waitForStreamReady(_ streamReady: @escaping () -> Bool) async -> Bool {
        let attempts = 40
        for _ in 0..<attempts {
            if streamReady() {
                return true
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return streamReady()
    }

    private func waitForFrame(_ frameProvider: @escaping () -> UIImage?) async -> UIImage? {
        let attempts = 20
        for _ in 0..<attempts {
            if let frame = frameProvider() {
                return frame
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return frameProvider()
    }

    private func waitForConnection() async -> Bool {
        let attempts = 20
        for _ in 0..<attempts {
            if isConnected {
                return true
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return isConnected
    }
}
