import Foundation

/// Streamed out of the conversion pipeline so the UI can show a live progress
/// bar and, on failure/cancellation, react appropriately. Emitted via an
/// `AsyncStream<ConversionProgress>`.
public struct ConversionProgress: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case extracting
        case synthesizing(chapterIndex: Int, segmentIndex: Int, segmentCount: Int)
        case encoding(chapterIndex: Int)
        case finished
        case failed(message: String)
        case cancelled
    }

    public var phase: Phase
    /// Total chapters in the book (0 until extraction completes).
    public var chapterCount: Int
    /// Chapters fully synthesized + encoded so far.
    public var completedChapters: Int
    /// Overall fraction complete in `0...1`.
    public var fractionComplete: Double

    public init(phase: Phase, chapterCount: Int, completedChapters: Int, fractionComplete: Double) {
        self.phase = phase
        self.chapterCount = chapterCount
        self.completedChapters = completedChapters
        self.fractionComplete = fractionComplete.clamped(to: 0...1)
    }

    public var isTerminal: Bool {
        switch phase {
        case .finished, .failed, .cancelled: return true
        default: return false
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
