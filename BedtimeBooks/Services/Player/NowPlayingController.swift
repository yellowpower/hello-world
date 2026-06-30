import Foundation
import MediaPlayer

/// Mirrors playback state into the lock screen / Control Center via
/// `MPNowPlayingInfoCenter` and wires the remote transport buttons
/// (`MPRemoteCommandCenter`) back to the player.
@MainActor
final class NowPlayingController {
    struct Handlers {
        var play: () -> Void
        var pause: () -> Void
        var next: () -> Void
        var previous: () -> Void
        var skipForward: (TimeInterval) -> Void
        var skipBackward: (TimeInterval) -> Void
        var seek: (TimeInterval) -> Void
    }

    private let skipInterval: TimeInterval = 15

    func registerCommands(_ handlers: Handlers) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { _ in handlers.play(); return .success }
        center.pauseCommand.addTarget { _ in handlers.pause(); return .success }
        center.togglePlayPauseCommand.addTarget { _ in handlers.play(); return .success }
        center.nextTrackCommand.addTarget { _ in handlers.next(); return .success }
        center.previousTrackCommand.addTarget { _ in handlers.previous(); return .success }

        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        center.skipForwardCommand.addTarget { _ in handlers.skipForward(self.skipInterval); return .success }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        center.skipBackwardCommand.addTarget { _ in handlers.skipBackward(self.skipInterval); return .success }

        center.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            handlers.seek(e.positionTime)
            return .success
        }
    }

    func update(title: String, bookTitle: String, author: String?,
                duration: TimeInterval, elapsed: TimeInterval, rate: Double, isPlaying: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyAlbumTitle: bookTitle,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? rate : 0.0,
            MPMediaItemPropertyMediaType: MPMediaType.audioBook.rawValue,
        ]
        if let author { info[MPMediaItemPropertyArtist] = author }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
