import Foundation
import AVFoundation

/// M1 TTS engine using Apple's on-device `AVSpeechSynthesizer`. No model
/// download, works offline immediately, and lets us prove the whole
/// import → convert → play pipeline before integrating neural TTS.
///
/// `write(_:toBufferCallback:)` streams PCM buffers and finally an empty buffer
/// to signal completion; we bridge that into async/await and collect the
/// non-empty buffers.
final class SystemTTSEngine: NSObject, TTSEngine {
    private let synthesizer = AVSpeechSynthesizer()
    private let voiceIdentifier: String?
    private let languageCode: String

    /// - Parameters:
    ///   - voiceIdentifier: an `AVSpeechSynthesisVoice.identifier`, or nil to
    ///     use the best available voice for `languageCode`.
    ///   - languageCode: BCP-47 language, used when no explicit voice is set.
    init(voiceIdentifier: String? = nil, languageCode: String = "en-US") {
        self.voiceIdentifier = voiceIdentifier
        self.languageCode = languageCode
        super.init()
    }

    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if let id = voiceIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return AVSpeechSynthesisVoice(language: languageCode)
    }

    func synthesize(text: String) async throws -> [AVAudioPCMBuffer] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = resolvedVoice()
        // Slightly slower, calmer delivery suits bedtime listening.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92

        return try await withCheckedThrowingContinuation { continuation in
            var collected: [AVAudioPCMBuffer] = []
            var finished = false

            synthesizer.write(utterance) { buffer in
                guard let pcm = buffer as? AVAudioPCMBuffer else { return }
                if pcm.frameLength == 0 {
                    // Empty buffer = end of stream.
                    guard !finished else { return }
                    finished = true
                    continuation.resume(returning: collected)
                    return
                }
                // Copy out of the callback-owned buffer so it survives.
                if let copy = pcm.deepCopy() {
                    collected.append(copy)
                }
            }
        }
    }
}

extension AVAudioPCMBuffer {
    /// Makes an independent copy of this buffer's frames. The buffers handed to
    /// the `write` callback are transient, so we copy before retaining them.
    func deepCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else { return nil }
        copy.frameLength = frameLength
        let channels = Int(format.channelCount)
        let frames = Int(frameLength)

        if let src = floatChannelData, let dst = copy.floatChannelData {
            for ch in 0..<channels {
                dst[ch].update(from: src[ch], count: frames)
            }
        } else if let src = int16ChannelData, let dst = copy.int16ChannelData {
            for ch in 0..<channels {
                dst[ch].update(from: src[ch], count: frames)
            }
        } else if let src = int32ChannelData, let dst = copy.int32ChannelData {
            for ch in 0..<channels {
                dst[ch].update(from: src[ch], count: frames)
            }
        } else {
            return nil
        }
        return copy
    }
}
