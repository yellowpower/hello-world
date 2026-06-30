import Foundation

/// A single chapter's worth of plain text pulled out of a source document,
/// before any audio has been synthesized.
public struct RawChapter: Equatable, Sendable {
    /// Heading text if the source had one (e.g. an EPUB `<h1>` or a Markdown
    /// `#` line). `nil` for formats/sections without an explicit title.
    public var title: String?
    /// Plain, normalized text ready to be chunked and spoken.
    public var text: String

    public init(title: String? = nil, text: String) {
        self.title = title
        self.text = text
    }

    /// True when there is nothing worth synthesizing (whitespace only).
    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// The result of running a `TextExtractor` over an imported file: a title plus
/// an ordered list of chapters. This is the hand-off between the extraction
/// layer and the conversion pipeline.
public struct ExtractedDocument: Equatable, Sendable {
    public var title: String
    public var chapters: [RawChapter]

    public init(title: String, chapters: [RawChapter]) {
        self.title = title
        self.chapters = chapters
    }

    /// Drops whitespace-only chapters. Useful right before conversion so we
    /// never spawn a TTS job for an empty section.
    public func prunedOfEmptyChapters() -> ExtractedDocument {
        ExtractedDocument(title: title, chapters: chapters.filter { !$0.isEmpty })
    }
}

/// Raised by extractors when a file can be opened but yields no usable text
/// (e.g. a scanned, image-only PDF). The UI turns this into a friendly message.
public struct NoExtractableTextError: Error, Equatable {
    public let filename: String
    public init(filename: String) { self.filename = filename }
}
