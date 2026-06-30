import Foundation
import AVFoundation

/// Synthesizes a text segment into in-memory PCM buffers. The conversion
/// pipeline owns file writing, silence insertion, and AAC encoding, so an
/// engine only has to turn text into audio buffers.
///
/// M1 ships `SystemTTSEngine` (Apple `AVSpeechSynthesizer`). M2 adds a
/// `NeuralTTSEngine` backed by sherpa-onnx (Kokoro) that conforms to this same
/// protocol and emits 24 kHz mono float buffers — the pipeline above it is
/// unchanged.
protocol TTSEngine: AnyObject {
    /// Synthesize `text`, returning ordered PCM buffers (all sharing one format).
    /// Returns an empty array for whitespace-only input.
    func synthesize(text: String) async throws -> [AVAudioPCMBuffer]
}

enum TTSError: LocalizedError {
    case synthesisFailed(String)
    case voiceUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .synthesisFailed(let m): return "Speech synthesis failed: \(m)"
        case .voiceUnavailable(let id): return "The selected voice (\(id)) isn't available on this device."
        }
    }
}
