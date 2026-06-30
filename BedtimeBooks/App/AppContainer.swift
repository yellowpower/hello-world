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

        // The engine factory picks the right TTS engine for a book's voice.
        let catalog = self.catalog
        self.conversion = ConversionService(
            storage: storage,
            extractors: extractors,
            makeEngine: { book in
                AppContainer.makeEngine(voiceID: book.voiceID, catalog: catalog)
            })
    }

    /// Resolves a `VoiceDescriptor` to a concrete `TTSEngine`. M1 always returns
    /// the system engine; M2 returns a `NeuralTTSEngine` for `.neural` voices.
    static func makeEngine(voiceID: String, catalog: VoiceCatalog) -> TTSEngine {
        let voice = catalog.voice(withID: voiceID)
        switch voice?.kind {
        case .neural:
            // M2: return NeuralTTSEngine(...). Until then, fall back gracefully.
            return SystemTTSEngine(languageCode: voice?.localeIdentifier ?? "en-US")
        case .system, .none:
            return SystemTTSEngine(languageCode: voice?.localeIdentifier ?? "en-US")
        }
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
