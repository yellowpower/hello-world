import Foundation
import AVFoundation

/// Factory + availability flag for the on-device neural engine. Always present
/// so the rest of the app can ask for a neural engine without `#if` clutter;
/// returns `nil` (and reports unavailable) until the sherpa-onnx frameworks are
/// vendored and `SHERPA_ENABLED` is set.
enum NeuralTTS {
    /// True when the app was built with the sherpa-onnx frameworks linked.
    static var isAvailable: Bool {
        #if SHERPA_ENABLED
        return true
        #else
        return false
        #endif
    }

    /// Builds a neural engine for a model directory + speaker, or nil if neural
    /// TTS isn't compiled in.
    static func makeEngine(modelDirectory: URL, speakerID: Int) -> TTSEngine? {
        #if SHERPA_ENABLED
        return NeuralTTSEngine(modelDirectory: modelDirectory, speakerID: speakerID)
        #else
        return nil
        #endif
    }
}

#if SHERPA_ENABLED
// NOTE: This file compiles only when the sherpa-onnx + onnxruntime xcframeworks
// are vendored (Scripts/build_sherpa_xcframework.sh) and SHERPA_ENABLED is set
// in project.yml. It uses the upstream `SherpaOnnx.swift` wrapper that the build
// script copies into Vendor/. The wrapper symbol names below match sherpa-onnx
// at the pinned tag; if you bump SHERPA_TAG, re-verify them.

/// On-device neural TTS using sherpa-onnx running a Kokoro model. Emits the
/// model's native PCM (24 kHz mono float) as an `AVAudioPCMBuffer`, which the
/// existing `ChapterAudioWriter` consumes unchanged.
final class NeuralTTSEngine: TTSEngine {
    private let tts: SherpaOnnxOfflineTtsWrapper
    private let speakerID: Int
    private let queue = DispatchQueue(label: "com.bedtimebooks.tts.neural", qos: .userInitiated)

    init(modelDirectory: URL, speakerID: Int, numThreads: Int = 2) {
        self.speakerID = speakerID
        let path = { (name: String) in modelDirectory.appendingPathComponent(name).path }

        var kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(
            model: path("model.onnx"),
            voices: path("voices.bin"),
            tokens: path("tokens.txt"),
            dataDir: path("espeak-ng-data"),
            lengthScale: 1.0
        )
        var model = sherpaOnnxOfflineTtsModelConfig(kokoro: kokoro, numThreads: numThreads)
        var config = sherpaOnnxOfflineTtsConfig(model: model)
        self.tts = SherpaOnnxOfflineTtsWrapper(config: &config)
    }

    func synthesize(text: String) async throws -> [AVAudioPCMBuffer] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Inference is synchronous and CPU-heavy — run it off the main actor.
        let generated: GeneratedAudioWrapper = try await withCheckedThrowingContinuation { cont in
            queue.async {
                let audio = self.tts.generate(text: trimmed, sid: self.speakerID, speed: 1.0)
                cont.resume(returning: audio)
            }
        }

        guard generated.sampleRate > 0, !generated.samples.isEmpty,
              let buffer = Self.makeBuffer(samples: generated.samples, sampleRate: Double(generated.sampleRate)) else {
            return []
        }
        return [buffer]
    }

    /// Wraps interleaved float samples (mono) into an `AVAudioPCMBuffer`.
    private static func makeBuffer(samples: [Float], sampleRate: Double) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let dst = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { src in
                dst[0].update(from: src.baseAddress!, count: samples.count)
            }
        }
        return buffer
    }
}
#endif
