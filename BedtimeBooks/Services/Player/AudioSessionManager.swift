import Foundation
import AVFoundation

/// Configures `AVAudioSession` for background, lock-screen audiobook playback
/// and surfaces interruptions (phone calls, Siri) and route changes (headphones
/// unplugged) to the player.
final class AudioSessionManager {
    enum Event {
        case interruptionBegan
        case interruptionEnded(shouldResume: Bool)
        case oldDeviceUnavailable   // e.g. headphones unplugged → should pause
    }

    /// Called on the main actor for session events.
    var onEvent: ((Event) -> Void)?

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification, object: nil)
    }

    /// `.playback` keeps audio going when the screen locks / app backgrounds
    /// (paired with the `audio` UIBackgroundMode in Info.plist).
    func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [])
        try session.setActive(true)
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            emit(.interruptionBegan)
        case .ended:
            var shouldResume = false
            if let optsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optsRaw).contains(.shouldResume)
            }
            emit(.interruptionEnded(shouldResume: shouldResume))
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        if reason == .oldDeviceUnavailable {
            emit(.oldDeviceUnavailable)
        }
    }

    private func emit(_ event: Event) {
        Task { @MainActor in self.onEvent?(event) }
    }
}
