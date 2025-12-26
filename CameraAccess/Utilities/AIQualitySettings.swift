import Combine
import Foundation

@MainActor
final class AIQualitySettings: ObservableObject {
    static let shared = AIQualitySettings()

    enum PreviewResolution: String, CaseIterable, Identifiable {
        case low
        case medium
        case high

        var id: String { rawValue }
    }

    enum AIImageDimension: Int, CaseIterable, Identifiable {
        case px512 = 512
        case px768 = 768
        case px1024 = 1024

        var id: Int { rawValue }
    }

    @Published var previewResolution: PreviewResolution {
        didSet { persist() }
    }
    @Published var aiImageMaxDimension: AIImageDimension {
        didSet { persist() }
    }
    @Published var aiImageQuality: Double {
        didSet { persist() }
    }
    @Published var keyFrameCount: Int {
        didSet { persist() }
    }

    private let userDefaults: UserDefaults
    private var isReloading = false

    private enum Keys {
        static let previewResolution = "ai.previewResolution"
        static let aiImageMaxDimension = "ai.imageMaxDimension"
        static let aiImageQuality = "ai.imageQuality"
        static let keyFrameCount = "ai.keyFrameCount"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        self.previewResolution = .low
        self.aiImageMaxDimension = .px768
        self.aiImageQuality = 0.8
        self.keyFrameCount = 1
        reload()
    }

    func reload() {
        isReloading = true
        defer { isReloading = false }

        let resolutionRaw = userDefaults.string(forKey: Keys.previewResolution)
        previewResolution = PreviewResolution(rawValue: resolutionRaw ?? "") ?? .low

        let dimensionValue = userDefaults.integer(forKey: Keys.aiImageMaxDimension)
        aiImageMaxDimension = AIImageDimension(rawValue: dimensionValue) ?? .px768

        let storedQuality = userDefaults.double(forKey: Keys.aiImageQuality)
        if storedQuality == 0 {
            aiImageQuality = 0.8
        } else {
            aiImageQuality = min(max(storedQuality, 0.6), 0.9)
        }

        let storedKeyFrames = userDefaults.integer(forKey: Keys.keyFrameCount)
        if storedKeyFrames == 0 {
            keyFrameCount = 1
        } else {
            keyFrameCount = min(max(storedKeyFrames, 1), 3)
        }
    }

    private func persist() {
        guard !isReloading else { return }
        userDefaults.set(previewResolution.rawValue, forKey: Keys.previewResolution)
        userDefaults.set(aiImageMaxDimension.rawValue, forKey: Keys.aiImageMaxDimension)
        userDefaults.set(aiImageQuality, forKey: Keys.aiImageQuality)
        userDefaults.set(keyFrameCount, forKey: Keys.keyFrameCount)
        userDefaults.synchronize()
    }
}
