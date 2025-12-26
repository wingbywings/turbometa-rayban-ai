import UIKit

final class AudioBackgroundSession {
    static let shared = AudioBackgroundSession()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    func begin() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "live-chat-audio") { [weak self] in
            self?.end()
        }
    }

    func end() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
