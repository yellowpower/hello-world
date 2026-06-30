import Foundation

/// Pulls plain, speakable text out of an imported document. One concrete
/// implementation per format; a registry picks the right one by file type.
///
/// Foundation-only extractors (plain text, Markdown) live here in Core so they
/// can be unit-tested anywhere. Extractors that need Apple frameworks or extra
/// SPM packages (PDFKit for PDF, ZIPFoundation + SwiftSoup for EPUB/DOCX) live
/// in the app target and conform to this same protocol.
public protocol TextExtractor: Sendable {
    /// Lowercased file extensions this extractor handles, e.g. `["txt"]`.
    var supportedExtensions: [String] { get }
    func extract(from url: URL) async throws -> ExtractedDocument
}

/// Reads a UTF-8 (or UTF-16/Latin-1 fallback) plain-text file and splits it
/// into chapters on runs of blank lines large enough to look like a section
/// break, falling back to a single chapter.
public struct PlainTextExtractor: TextExtractor {
    public var supportedExtensions: [String] { ["txt", "text"] }

    public init() {}

    public func extract(from url: URL) async throws -> ExtractedDocument {
        let raw = try Self.readText(at: url)
        let title = url.deletingPathExtension().lastPathComponent
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")

        // Treat 3+ consecutive newlines as a chapter break; otherwise it's all
        // one chapter. This keeps simple notes as one piece while letting a
        // user pre-format a book with big gaps between chapters.
        let blocks = normalized
            .components(separatedBy: "\n\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let chapters: [RawChapter]
        if blocks.count <= 1 {
            let body = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { throw NoExtractableTextError(filename: url.lastPathComponent) }
            chapters = [RawChapter(title: nil, text: body)]
        } else {
            chapters = blocks.map { RawChapter(title: nil, text: $0) }
        }
        return ExtractedDocument(title: title, chapters: chapters)
    }

    static func readText(at url: URL) throws -> String {
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) { return utf8 }
        if let utf16 = try? String(contentsOf: url, encoding: .utf16) { return utf16 }
        return try String(contentsOf: url, encoding: .isoLatin1)
    }
}

/// A lightweight Markdown-to-text extractor for M1: it strips the most common
/// inline/structural Markdown and turns `#`/`##` headings into chapter breaks.
/// (M3 can swap this for `apple/swift-markdown` AST walking for full fidelity —
/// the protocol and chapter shape stay identical.)
public struct MarkdownExtractor: TextExtractor {
    public var supportedExtensions: [String] { ["md", "markdown"] }

    public init() {}

    public func extract(from url: URL) async throws -> ExtractedDocument {
        let raw = try PlainTextExtractor.readText(at: url)
        let title = url.deletingPathExtension().lastPathComponent
        let document = Self.parse(raw)
        guard !document.chapters.isEmpty else {
            throw NoExtractableTextError(filename: url.lastPathComponent)
        }
        return ExtractedDocument(title: title, chapters: document.chapters)
    }

    /// Splits on level-1/2 ATX headings and strips inline markup from the body.
    static func parse(_ markdown: String) -> ExtractedDocument {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var chapters: [RawChapter] = []
        var currentTitle: String? = nil
        var currentBody: [String] = []

        func commit() {
            let body = currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty || currentTitle != nil {
                let text = body.isEmpty ? (currentTitle ?? "") : body
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chapters.append(RawChapter(title: currentTitle, text: text))
                }
            }
            currentTitle = nil
            currentBody = []
        }

        for line in lines {
            if let heading = headingText(line, maxLevel: 2) {
                commit()
                currentTitle = heading
            } else {
                currentBody.append(stripInline(line))
            }
        }
        commit()
        return ExtractedDocument(title: "", chapters: chapters)
    }

    /// Returns the heading text for `#`/`##` lines (within `maxLevel`), else nil.
    static func headingText(_ line: String, maxLevel: Int) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }
        let hashes = trimmed.prefix { $0 == "#" }
        guard hashes.count <= maxLevel,
              trimmed.dropFirst(hashes.count).first == " " else { return nil }
        return stripInline(String(trimmed.dropFirst(hashes.count)).trimmingCharacters(in: .whitespaces))
    }

    /// Removes the most common inline Markdown so the spoken text is clean.
    static func stripInline(_ line: String) -> String {
        var s = line
        // List/quote markers at line start.
        s = s.replacingOccurrences(of: #"^\s*([-*+]|\d+\.)\s+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^\s*>\s?"#, with: "", options: .regularExpression)
        // Images and links: keep the visible text.
        s = s.replacingOccurrences(of: #"!\[([^\]]*)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
        // Emphasis / inline code markers.
        s = s.replacingOccurrences(of: #"[*_`~]"#, with: "", options: .regularExpression)
        return s
    }
}
