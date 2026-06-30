import Foundation
import Observation

/// The bedtime centerpiece: counts down, then asks the player to fade out and
/// pause. Supports fixed durations and "end of current chapter". `@Observable`
/// so the remaining-time label updates live in the player UI.
@MainActor
@Observable
final class SleepTimer {
    enum Option: Equatable, Identifiable, CaseIterable {
        case off
        case minutes(Int)
        case endOfChapter

        static var allCases: [Option] {
            [.off, .minutes(5), .minutes(10), .minutes(15), .minutes(30), .minutes(45), .minutes(60), .endOfChapter]
        }

        var id: String {
            switch self {
            case .off: return "off"
            case .minutes(let m): return "min-\(m)"
            case .endOfChapter: return "eoc"
            }
        }

        var label: String {
            switch self {
            case .off: return "Off"
            case .minutes(let m): return "\(m) min"
            case .endOfChapter: return "End of chapter"
            }
        }
    }

    private(set) var option: Option = .off
    /// Remaining seconds for a timed countdown (nil for off / end-of-chapter).
    private(set) var remaining: TimeInterval?

    @ObservationIgnored private var ticker: Timer?
    /// Invoked when the timer fires (fixed duration elapsed). The player fades
    /// and pauses. End-of-chapter is handled by the player observing chapter end.
    @ObservationIgnored var onFire: (() -> Void)?

    var isActive: Bool { option != .off }
    var stopsAtEndOfChapter: Bool { option == .endOfChapter }

    func set(_ option: Option) {
        cancelTicker()
        self.option = option
        switch option {
        case .off, .endOfChapter:
            remaining = nil
        case .minutes(let m):
            remaining = TimeInterval(m * 60)
            startTicker()
        }
    }

    func cancel() { set(.off) }

    private func startTicker() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func tick() {
        guard var r = remaining else { return }
        r -= 1
        remaining = r
        if r <= 0 {
            cancelTicker()
            option = .off
            remaining = nil
            onFire?()
        }
    }

    private func cancelTicker() {
        ticker?.invalidate()
        ticker = nil
    }
}
