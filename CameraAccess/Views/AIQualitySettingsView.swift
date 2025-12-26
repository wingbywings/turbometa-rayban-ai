import SwiftUI

struct AIQualitySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: AIQualitySettings

    private let qualities: [Double] = [0.6, 0.7, 0.8, 0.9]

    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker(NSLocalizedString("settings.ai.vision.preview", comment: "Preview resolution"), selection: $settings.previewResolution) {
                        Text(NSLocalizedString("settings.ai.vision.preview.low", comment: "Low"))
                            .tag(AIQualitySettings.PreviewResolution.low)
                        Text(NSLocalizedString("settings.ai.vision.preview.medium", comment: "Medium"))
                            .tag(AIQualitySettings.PreviewResolution.medium)
                        Text(NSLocalizedString("settings.ai.vision.preview.high", comment: "High"))
                            .tag(AIQualitySettings.PreviewResolution.high)
                    }
                    .pickerStyle(.segmented)
                    Text(NSLocalizedString("settings.ai.vision.restart", comment: "Restart tip"))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                } header: {
                    Text(NSLocalizedString("settings.ai.vision.preview", comment: "Preview"))
                }

                Section {
                    Picker(NSLocalizedString("settings.ai.vision.image.resolution", comment: "AI image resolution"), selection: $settings.aiImageMaxDimension) {
                        Text("512px").tag(AIQualitySettings.AIImageDimension.px512)
                        Text("768px").tag(AIQualitySettings.AIImageDimension.px768)
                        Text("1024px").tag(AIQualitySettings.AIImageDimension.px1024)
                    }

                    Picker(NSLocalizedString("settings.ai.vision.image.quality", comment: "AI image quality"), selection: $settings.aiImageQuality) {
                        ForEach(qualities, id: \.self) { value in
                            Text(String(format: "%.1f", value)).tag(value)
                        }
                    }

                    Picker(NSLocalizedString("settings.ai.vision.keyframes", comment: "Keyframes"), selection: $settings.keyFrameCount) {
                        Text(NSLocalizedString("settings.ai.vision.keyframes.1", comment: "1 frame")).tag(1)
                        Text(NSLocalizedString("settings.ai.vision.keyframes.2", comment: "2 frames")).tag(2)
                        Text(NSLocalizedString("settings.ai.vision.keyframes.3", comment: "3 frames")).tag(3)
                    }

                    Text(NSLocalizedString("settings.ai.vision.keyframes.tip", comment: "Keyframe tip"))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                } header: {
                    Text(NSLocalizedString("settings.ai.vision.image", comment: "AI image"))
                }
            }
            .navigationTitle(NSLocalizedString("settings.ai.vision", comment: "AI vision settings"))
            .onAppear {
                settings.reload()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
