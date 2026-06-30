import Foundation
import SwiftData

/// Where a book is in its lifecycle from import to playable audiobook.
enum ConversionState: String, Codable {
    case pending      // imported, text not yet extracted/converted
    case extracting
    case converting
    case ready        // all chapters synthesized and playable
    case failed
}

/// A book in the user's library. The SwiftData root object; owns its chapters.
/// File paths it references (cover, per-chapter audio) are stored **relative**
/// and resolved at runtime via `FileLayout` — see Services/Storage.
@Model
final class Book {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String?
    /// Original imported filename, e.g. "the-sleepy-dragon.epub".
    var sourceFilename: String
    var importedAt: Date

    /// Relative path to a cover image, if we have one.
    var coverRelativePath: String?

    /// The voice (`VoiceDescriptor.id`) used to synthesize this book.
    var voiceID: String
    /// Persisted playback speed, 0.5...2.0.
    var playbackRate: Double

    /// Raw value of `ConversionState`; stored as String for forward-compat.
    var conversionStateRaw: String
    /// Last user-readable error when `conversionState == .failed`.
    var lastErrorMessage: String?

    /// Resume bookkeeping: which chapter the user was last in.
    var lastPlayedChapterIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \Chapter.book)
    var chapters: [Chapter]

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        sourceFilename: String,
        voiceID: String,
        importedAt: Date = Date(),
        playbackRate: Double = 1.0
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.sourceFilename = sourceFilename
        self.voiceID = voiceID
        self.importedAt = importedAt
        self.playbackRate = playbackRate
        self.conversionStateRaw = ConversionState.pending.rawValue
        self.lastPlayedChapterIndex = 0
        self.chapters = []
    }

    var conversionState: ConversionState {
        get { ConversionState(rawValue: conversionStateRaw) ?? .pending }
        set { conversionStateRaw = newValue.rawValue }
    }

    /// Chapters in playback order.
    var orderedChapters: [Chapter] {
        chapters.sorted { $0.index < $1.index }
    }

    /// Total duration across all synthesized chapters, in seconds.
    var totalDuration: TimeInterval {
        chapters.reduce(0) { $0 + $1.duration }
    }

    var isReady: Bool { conversionState == .ready }
}
