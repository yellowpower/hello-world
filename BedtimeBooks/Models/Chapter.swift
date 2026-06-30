import Foundation
import SwiftData

/// One chapter of a book: its source text plus, once converted, the synthesized
/// audio file and playback bookkeeping. One `.m4a` file per chapter gives us
/// free chapter navigation in the player.
@Model
final class Chapter {
    /// 0-based playback order within the book.
    var index: Int
    var title: String?
    /// The plain text that was (or will be) synthesized.
    var text: String

    /// Relative path to this chapter's audio, set once synthesized.
    var audioRelativePath: String?
    /// Duration of the synthesized audio in seconds (0 until ready).
    var duration: TimeInterval
    var isSynthesized: Bool

    /// Resume point within this chapter, in seconds.
    var positionInChapter: TimeInterval

    var book: Book?

    init(index: Int, title: String?, text: String) {
        self.index = index
        self.title = title
        self.text = text
        self.duration = 0
        self.isSynthesized = false
        self.positionInChapter = 0
    }

    /// A user-facing label, falling back to "Chapter N" when untitled.
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        return "Chapter \(index + 1)"
    }
}
