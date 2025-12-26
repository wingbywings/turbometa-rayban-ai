/*
 * Conversation Image Storage
 */

import Foundation
import UIKit

final class ConversationImageStorage {
    static let shared = ConversationImageStorage()

    private let fileManager = FileManager.default
    private let directoryURL: URL

    private init() {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directoryURL = baseURL.appendingPathComponent("ConversationImages", isDirectory: true)
        createDirectoryIfNeeded()
    }

    func saveAttachment(_ image: UIImage, aiMaxDimension: Int, aiQuality: Double) -> ConversationImageAttachment? {
        let previewImage = resizeImage(image, maxDimension: aiMaxDimension)
        let previewQuality = min(max(aiQuality, 0.4), 0.95)

        guard let previewData = previewImage.jpegData(compressionQuality: previewQuality) else {
            print("[ImageStorage] Failed to encode preview image")
            return nil
        }

        createDirectoryIfNeeded()

        let attachmentID = UUID()
        let previewFileName = "\(attachmentID.uuidString)-preview.jpg"
        let previewURL = url(for: previewFileName)

        do {
            try previewData.write(to: previewURL, options: [.atomic])
        } catch {
            print("[ImageStorage] Failed to save preview image: \(error.localizedDescription)")
            return nil
        }

        let originalMaxDimension = min(max(aiMaxDimension * 2, 1024), 2048)
        let originalImage = resizeImage(image, maxDimension: originalMaxDimension)
        let originalQuality = min(max(aiQuality + 0.1, 0.7), 0.95)
        var originalFileName: String?

        if let originalData = originalImage.jpegData(compressionQuality: originalQuality) {
            let originalName = "\(attachmentID.uuidString)-original.jpg"
            let originalURL = url(for: originalName)
            do {
                try originalData.write(to: originalURL, options: [.atomic])
                originalFileName = originalName
            } catch {
                print("[ImageStorage] Failed to save original image: \(error.localizedDescription)")
            }
        } else {
            print("[ImageStorage] Failed to encode original image")
        }

        return ConversationImageAttachment(
            id: attachmentID,
            fileName: previewFileName,
            originalFileName: originalFileName
        )
    }

    func loadPreviewImage(_ attachment: ConversationImageAttachment) -> UIImage? {
        let fileURL = url(for: attachment.fileName)
        return UIImage(contentsOfFile: fileURL.path)
    }

    func loadOriginalImage(_ attachment: ConversationImageAttachment) -> UIImage? {
        if let originalName = attachment.originalFileName {
            let fileURL = url(for: originalName)
            if let image = UIImage(contentsOfFile: fileURL.path) {
                return image
            }
        }
        return loadPreviewImage(attachment)
    }

    func deleteImages(_ attachments: [ConversationImageAttachment]) {
        let fileNames = Set(attachments.flatMap { attachment in
            [attachment.fileName, attachment.originalFileName].compactMap { $0 }
        })

        for fileName in fileNames {
            let fileURL = url(for: fileName)
            if fileManager.fileExists(atPath: fileURL.path) {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    func deleteImages(in record: ConversationRecord) {
        let attachments = record.messages.flatMap { $0.imageAttachments }
        deleteImages(attachments)
    }

    func deleteAllImages() {
        if fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.removeItem(at: directoryURL)
        }
        createDirectoryIfNeeded()
    }

    private func url(for fileName: String) -> URL {
        directoryURL.appendingPathComponent(fileName)
    }

    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    private func resizeImage(_ image: UIImage, maxDimension: Int) -> UIImage {
        guard maxDimension > 0 else { return image }
        let size = image.size
        let maxSide = max(size.width, size.height)

        guard maxSide > CGFloat(maxDimension) else { return image }

        let scale = CGFloat(maxDimension) / maxSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
