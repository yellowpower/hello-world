import Foundation
import AVFoundation

/// Streams synthesized PCM buffers into a single AAC `.m4a` file for one
/// chapter, inserting short silences for natural pacing. The output format
/// (sample rate / channel count) is taken from the first buffer, so it works
/// for both the system engine and the future 24 kHz neural engine without
/// changes.
final class ChapterAudioWriter {
    private let outputURL: URL
    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var processingFormat: AVAudioFormat?
    private(set) var framesWritten: AVAudioFramePosition = 0
    private var sampleRate: Double = 0

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    /// Lazily creates the AAC file and a converter from the first buffer's PCM
    /// format into the file's processing format.
    private func prepareIfNeeded(from buffer: AVAudioPCMBuffer) throws {
        guard file == nil else { return }
        let inFormat = buffer.format
        sampleRate = inFormat.sampleRate

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: inFormat.sampleRate,
            AVNumberOfChannelsKey: inFormat.channelCount,
            AVEncoderBitRateKey: 64_000,
        ]
        let f = try AVAudioFile(forWriting: outputURL, settings: settings)
        // Channels/sample-rate match the input, so this is a bit-depth/interleave
        // conversion only (frame-count preserving) — no resampling.
        guard let conv = AVAudioConverter(from: inFormat, to: f.processingFormat) else {
            throw TTSError.synthesisFailed("Could not create audio converter")
        }
        file = f
        converter = conv
        processingFormat = f.processingFormat
    }

    func append(_ buffer: AVAudioPCMBuffer) throws {
        guard buffer.frameLength > 0 else { return }
        try prepareIfNeeded(from: buffer)
        guard let file, let converter, let processingFormat else { return }

        guard let out = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: buffer.frameCapacity) else {
            throw TTSError.synthesisFailed("Could not allocate output buffer")
        }
        // Input and output share sample rate + channel count, so this is a
        // bit-depth/interleave conversion only — the one-shot `convert(to:from:)`
        // is exact and avoids the pull-callback's re-feed pitfalls.
        try converter.convert(to: out, from: buffer)
        try file.write(from: out)
        framesWritten += AVAudioFramePosition(out.frameLength)
    }

    /// Writes `seconds` of silence in the processing format. No-op before the
    /// first real buffer (we don't yet know the format).
    func appendSilence(seconds: Double) throws {
        guard seconds > 0, let file, let processingFormat else { return }
        let frames = AVAudioFrameCount(seconds * processingFormat.sampleRate)
        guard frames > 0, let silence = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frames) else { return }
        silence.frameLength = frames
        // AVAudioPCMBuffer zero-fills its channel data on allocation.
        try file.write(from: silence)
        framesWritten += AVAudioFramePosition(frames)
    }

    /// Finalizes the file and returns its duration in seconds.
    func finish() -> TimeInterval {
        let duration = sampleRate > 0 ? Double(framesWritten) / sampleRate : 0
        file = nil  // releasing the AVAudioFile flushes/closes it
        converter = nil
        return duration
    }
}
