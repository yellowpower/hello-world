import Foundation

/// How a voice's audio is produced.
public enum VoiceKind: String, Codable, Sendable, Equatable {
    /// Apple's on-device `AVSpeechSynthesizer`. No download, ships with iOS.
    case system
    /// An on-device neural model run through sherpa-onnx (Kokoro / Piper / VITS).
    case neural
}

/// Where a neural voice's model files come from.
public enum VoiceSource: String, Codable, Sendable, Equatable {
    /// Pulled via On-Demand Resources at first use (default voice).
    case onDemandResource
    /// Downloaded over HTTPS into Application Support (optional voices).
    case download
    /// Not applicable (system voices).
    case none
}

/// A selectable voice, decoded from the bundled `voices.json`. Neural entries
/// carry the metadata needed to fetch the model and to attribute its license.
public struct VoiceDescriptor: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var kind: VoiceKind
    public var localeIdentifier: String
    /// Short blurb shown in the picker ("Warm female, great for bedtime").
    public var blurb: String

    // Neural-only fields (nil/empty for system voices):
    public var source: VoiceSource
    /// The sherpa-onnx speaker id within a multi-speaker model (Kokoro uses 0+).
    public var speakerID: Int?
    /// ODR tag or download base URL depending on `source`.
    public var resourceReference: String?
    /// Approximate on-disk size in megabytes, for the download prompt.
    public var approxSizeMB: Int?
    /// SPDX license id of the model weights (e.g. "Apache-2.0").
    public var license: String?
    public var attribution: String?

    public init(
        id: String,
        displayName: String,
        kind: VoiceKind,
        localeIdentifier: String,
        blurb: String,
        source: VoiceSource = .none,
        speakerID: Int? = nil,
        resourceReference: String? = nil,
        approxSizeMB: Int? = nil,
        license: String? = nil,
        attribution: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.localeIdentifier = localeIdentifier
        self.blurb = blurb
        self.source = source
        self.speakerID = speakerID
        self.resourceReference = resourceReference
        self.approxSizeMB = approxSizeMB
        self.license = license
        self.attribution = attribution
    }
}

/// The decoded `voices.json` document: the list of available voices plus which
/// one is the default.
public struct VoiceCatalog: Codable, Sendable, Equatable {
    public var defaultVoiceID: String
    public var voices: [VoiceDescriptor]

    public init(defaultVoiceID: String, voices: [VoiceDescriptor]) {
        self.defaultVoiceID = defaultVoiceID
        self.voices = voices
    }

    /// Decodes a catalog from JSON `Data` (the bundled resource).
    public static func decode(from data: Data) throws -> VoiceCatalog {
        try JSONDecoder().decode(VoiceCatalog.self, from: data)
    }

    public func voice(withID id: String) -> VoiceDescriptor? {
        voices.first { $0.id == id }
    }

    public var defaultVoice: VoiceDescriptor? {
        voice(withID: defaultVoiceID)
    }
}
