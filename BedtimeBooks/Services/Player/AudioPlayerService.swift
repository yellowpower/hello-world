import Foundation
import AVFoundation
import Observation
import BedtimeBooksCore

/// One playable chapter in the player's queue.
struct PlaybackItem: Identifiable, Equatable {
    let id: Int            // chapter index
    let title: String
    let url: URL
    let duration: TimeInterval
}

/// Everything the player needs to start a book, including where to resume.
struct PlaybackQueue: Equatable {
    let bookID: UUID
    let bookTitle: String
    let author: String?
    let items: [PlaybackItem]
    var startIndex: Int
    var startPosition: TimeInterval
}

/// Receives throttled resume-position updates so the library can persist them.
@MainActor
protocol PlaybackPersistence: AnyObject {
    func persistPlayback(bookID: UUID, chapterIndex: Int, position: TimeInterval)
}

/// The bedtime audio player: sequential per-chapter `.m4a` playback with speed
/// control, background/lock-screen support, a sleep timer that fades out, and
/// resume persistence. `@Observable` so SwiftUI views update automatically.
@MainActor
@Observable
final class AudioPlayerService {
    // Observable playback state.
    private(set) var queue: PlaybackQueue?
    private(set) var currentIndex: Int = 0
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var currentDuration: TimeInterval = 0
    var playbackRate: Double = 1.0 {
        didSet { applyRate() }
    }

    let sleepTimer = SleepTimer()

    // Non-observed collaborators.
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private let session = AudioSessionManager()
    @ObservationIgnored private let nowPlaying = NowPlayingController()
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var lastPersist: Date = .distantPast
    @ObservationIgnored private var delegateProxy: PlayerDelegateProxy?
    @ObservationIgnored weak var persistence: PlaybackPersistence?

    init() {
        configureCommands()
        configureSession()
        configureSleepTimer()
    }

    var currentItem: PlaybackItem? {
        guard let queue, queue.items.indices.contains(currentIndex) else { return nil }
        return queue.items[currentIndex]
    }

    // MARK: Loading

    func load(_ queue: PlaybackQueue, autoplay: Bool = false) {
        self.queue = queue
        currentIndex = min(max(queue.startIndex, 0), max(queue.items.count - 1, 0))
        prepareCurrent(startAt: queue.startPosition)
        if autoplay { play() }
    }

    private func prepareCurrent(startAt position: TimeInterval = 0) {
        guard let item = currentItem else { return }
        do {
            let p = try AVAudioPlayer(contentsOf: item.url)
            p.enableRate = true
            p.rate = Float(playbackRate)
            let proxy = PlayerDelegateProxy { [weak self] success in
                Task { @MainActor in self?.chapterDidFinish(success: success) }
            }
            p.delegate = proxy
            p.prepareToPlay()
            p.currentTime = min(position, max(p.duration - 0.1, 0))
            player = p
            delegateProxy = proxy
            currentDuration = p.duration > 0 ? p.duration : item.duration
            currentTime = p.currentTime
        } catch {
            player = nil
            currentDuration = item.duration
        }
        updateNowPlaying()
    }

    // MARK: Transport

    func play() {
        guard let player else { return }
        try? session.activate()
        player.rate = Float(playbackRate)
        player.play()
        isPlaying = true
        startTicker()
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTicker()
        persist(force: true)
        updateNowPlaying()
    }

    func togglePlayPause() { isPlaying ? pause() : play() }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        player.currentTime = min(max(time, 0), player.duration)
        currentTime = player.currentTime
        updateNowPlaying()
    }

    func skip(by seconds: TimeInterval) {
        seek(to: currentTime + seconds)
    }

    func next() {
        guard let queue, currentIndex + 1 < queue.items.count else { return }
        advance(to: currentIndex + 1, autoplay: isPlaying)
    }

    func previous() {
        // Mirror typical players: restart chapter if >3s in, else go back one.
        if currentTime > 3 {
            seek(to: 0)
        } else if currentIndex > 0 {
            advance(to: currentIndex - 1, autoplay: isPlaying)
        } else {
            seek(to: 0)
        }
    }

    func jumpToChapter(_ index: Int) {
        guard let queue, queue.items.indices.contains(index) else { return }
        advance(to: index, autoplay: isPlaying)
    }

    private func advance(to index: Int, autoplay: Bool) {
        currentIndex = index
        prepareCurrent()
        persist(force: true)
        if autoplay { play() }
    }

    // MARK: Chapter completion

    private func chapterDidFinish(success: Bool) {
        if sleepTimer.stopsAtEndOfChapter {
            fadeOutAndPause()
            sleepTimer.cancel()
            return
        }
        if let queue, currentIndex + 1 < queue.items.count {
            advance(to: currentIndex + 1, autoplay: true)
        } else {
            isPlaying = false
            stopTicker()
            currentTime = currentDuration
            persist(force: true)
            updateNowPlaying()
        }
    }

    // MARK: Sleep timer / fade

    private func configureSleepTimer() {
        sleepTimer.onFire = { [weak self] in self?.fadeOutAndPause() }
    }

    /// Ramps volume to zero over ~6s, then pauses and restores volume for next time.
    func fadeOutAndPause() {
        guard let player, isPlaying else { pause(); return }
        player.setVolume(0, fadeDuration: 6)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_200_000_000)
            self.pause()
            self.player?.volume = 1
        }
    }

    // MARK: Rate

    private func applyRate() {
        player?.rate = Float(playbackRate)
        if isPlaying { player?.play() }
        updateNowPlaying()
    }

    // MARK: Ticker / persistence

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate(); ticker = nil
    }

    private func tick() {
        guard let player else { return }
        currentTime = player.currentTime
        persist(force: false)
    }

    private func persist(force: Bool) {
        guard let queue else { return }
        let now = Date()
        if !force && now.timeIntervalSince(lastPersist) < 5 { return }
        lastPersist = now
        persistence?.persistPlayback(bookID: queue.bookID, chapterIndex: currentIndex, position: currentTime)
    }

    // MARK: Wiring

    private func configureSession() {
        session.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .interruptionBegan:
                self.pause()
            case .interruptionEnded(let resume):
                if resume { self.play() }
            case .oldDeviceUnavailable:
                self.pause()
            }
        }
    }

    private func configureCommands() {
        nowPlaying.registerCommands(.init(
            play: { [weak self] in self?.play() },
            pause: { [weak self] in self?.pause() },
            next: { [weak self] in self?.next() },
            previous: { [weak self] in self?.previous() },
            skipForward: { [weak self] in self?.skip(by: $0) },
            skipBackward: { [weak self] in self?.skip(by: -$0) },
            seek: { [weak self] in self?.seek(to: $0) }
        ))
    }

    private func updateNowPlaying() {
        guard let queue, let item = currentItem else { nowPlaying.clear(); return }
        nowPlaying.update(
            title: item.title, bookTitle: queue.bookTitle, author: queue.author,
            duration: currentDuration, elapsed: currentTime, rate: playbackRate, isPlaying: isPlaying)
    }
}

/// Bridges `AVAudioPlayerDelegate` (an Obj-C delegate) to a Swift closure so the
/// `@Observable` service doesn't have to be an `NSObject`.
private final class PlayerDelegateProxy: NSObject, AVAudioPlayerDelegate {
    let onFinish: (Bool) -> Void
    init(onFinish: @escaping (Bool) -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish(flag)
    }
}
