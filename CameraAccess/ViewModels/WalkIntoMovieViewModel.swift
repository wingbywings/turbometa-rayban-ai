/*
 * Walk Into Movie ViewModel
 * 走进电影 - 识别与语音输出
 */

import AudioToolbox
import Foundation
import SwiftUI
import UIKit

@MainActor
final class WalkIntoMovieViewModel: ObservableObject {
    @Published var isAnalyzing = false
    @Published var result: WalkIntoMovieResult?
    @Published var errorMessage: String?
    @Published var isSocketConnected = false
    @Published var isSocketConnecting = false
    @Published var capturedImage: UIImage?

    private let omniService: OmniRealtimeService
    private let qualitySettings: AIQualitySettings
    private var analysisTask: Task<Void, Never>?
    private var currentTranscript = ""
    private var hasSentAudioPrimer = false
    private let startSoundID: SystemSoundID = 1104

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
        isSocketConnected = false
        isSocketConnecting = false
        isAnalyzing = false
        capturedImage = nil
        hasSentAudioPrimer = false
    }

    private func setupCallbacks() {
        omniService.onConnected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.isSocketConnected = true
                self?.isSocketConnecting = false
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
                if !finalText.isEmpty {
                    print("[WalkIntoMovie] AI response: \(finalText)")
                }
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
                guard let self else { return }
                self.errorMessage = message
                self.isAnalyzing = false
                self.resetConnection()
            }
        }
    }

    func prepareConnection() {
        errorMessage = nil
        connectIfNeeded()
    }

    private func captureAndAnalyze(
        frameProvider: @escaping () -> UIImage?,
        streamReady: @escaping () -> Bool
    ) async {
        isAnalyzing = true
        playStartSound()
        errorMessage = nil
        result = nil
        currentTranscript = ""
        capturedImage = nil

        connectIfNeeded()

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
            resetConnection()
            return
        }

        beginNewSession()
        sendAudioPrimerIfNeeded()

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

        capturedImage = frame

        let maxDimension = qualitySettings.aiImageMaxDimension.rawValue
        let quality = qualitySettings.aiImageQuality
        omniService.sendImageAppend(
            frame,
            maxDimension: maxDimension,
            quality: quality,
            maxImageBase64Length: 200_000
        )
        omniService.sendUserMessage(
            text: WalkIntoMovieService.userPrompt,
            image: nil,
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
            if isSocketConnected {
                return true
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
        return isSocketConnected
    }

    private func connectIfNeeded() {
        guard !isSocketConnected, !isSocketConnecting else { return }
        isSocketConnecting = true
        omniService.connect()
    }

    private func resetConnection() {
        omniService.disconnect()
        isSocketConnected = false
        isSocketConnecting = false
        hasSentAudioPrimer = false
    }

    private func beginNewSession() {
        hasSentAudioPrimer = false
        let sessionId = UUID().uuidString.prefix(8)
        let instructions = """
        \(WalkIntoMovieService.prompt)

        【会话ID: \(sessionId)】
        这是一次全新的会话，请忽略之前的对话和结果。
        """
        omniService.updateSessionInstructions(instructions)
    }

    private func sendAudioPrimerIfNeeded() {
        guard !hasSentAudioPrimer else { return }
        // Send a short silent buffer so image append is accepted by the realtime protocol.
        let sampleRate = 24_000
        let durationMs = 120
        let sampleCount = max(1, sampleRate * durationMs / 1000)
        let silenceSamples = [Int16](repeating: 0, count: sampleCount)
        let silenceData = silenceSamples.withUnsafeBytes { Data($0) }
        let base64Audio = silenceData.base64EncodedString()
        omniService.sendAudioAppend(base64Audio)
        omniService.commitAudioBuffer()
        hasSentAudioPrimer = true
    }

    private func playStartSound() {
        AudioServicesPlaySystemSound(startSoundID)
    }
}
