import Foundation
import SwiftUI
import Observation
import BedtimeBooksCore

/// Lightweight dependency container: builds and holds the long-lived services
/// and the voice catalog, and is injected into the SwiftUI environment.
@MainActor
@Observable
final class AppContainer {
    let storage: StorageService
    let extractors: TextExtractorRegistry
    let conversion: ConversionService
    let player: AudioPlayerService
    let catalog: VoiceCatalog
    let modelDownloader: ModelDownloader

    /// Currently selected voice id (persisted in UserDefaults).
    var selectedVoiceID: String {
        didSet { UserDefaults.standard.set(selectedVoiceID, forKey: Self.voiceKey) }
    }

    private static let voiceKey = "selectedVoiceID"

    init() {
        // Storage must succeed for the app to function; a failure here is a
        // programmer/filesystem error, so we trap with a clear message.
        guard let storage = try? StorageService() else {
            fatalError("Could not create application storage directory")
        }
        self.storage = storage
        self.extractors = .makeDefault()
        self.catalog = Self.loadCatalog()
        self.player = AudioPlayerService()

        let saved = UserDefaults.standard.string(forKey: Self.voiceKey)
        self.selectedVoiceID = saved ?? catalog.defaultVoiceID

        let downloader = ModelDownloader(storage: storage)
        self.modelDownloader = downloader

        // The engine factory picks the right TTS engine for a book's voice:
        // the neural engine when it's compiled in AND the model is installed,
        // otherwise Apple's system voice.
        let catalog = self.catalog
        self.conversion = ConversionService(
            storage: storage,
            extractors: extractors,
            makeEngine: { book in
                AppContainer.makeEngine(voiceID: book.voiceID, catalog: catalog, downloader: downloader)
            })
    }

    /// Resolves a voice id to a concrete `TTSEngine`. Uses the neural engine only
    /// when sherpa-onnx is compiled in and the model is already on disk; falls
    /// back to the system voice otherwise so conversion never blocks on a
    /// missing download.
    @MainActor
    static func makeEngine(voiceID: String, catalog: VoiceCatalog, downloader: ModelDownloader) -> TTSEngine {
        let voice = catalog.voice(withID: voiceID)
        if voice?.kind == .neural, NeuralTTS.isAvailable, downloader.isInstalled(voiceID),
           let engine = NeuralTTS.makeEngine(modelDirectory: downloader.modelDirectory(for: voiceID),
                                             speakerID: voice?.speakerID ?? 0) {
            return engine
        }
        return SystemTTSEngine(languageCode: voice?.localeIdentifier ?? "en-US")
    }

    private static func loadCatalog() -> VoiceCatalog {
        if let url = Bundle.main.url(forResource: "voices", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let catalog = try? VoiceCatalog.decode(from: data) {
            return catalog
        }
        // Fallback so the app still runs if the resource is missing.
        return VoiceCatalog(defaultVoiceID: "system-en", voices: [
            VoiceDescriptor(id: "system-en", displayName: "Built-in Voice", kind: .system,
                            localeIdentifier: "en-US", blurb: "Always available, no download")
        ])
    }
}
