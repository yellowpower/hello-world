import Foundation
import ZIPFoundation
import BedtimeBooksCore

/// EPUB extraction: an `.epub` is a ZIP of XHTML. We unzip the whole container
/// to a temporary directory (via ZIPFoundation's stable `FileManager` API) and
/// delegate all XML parsing to `BedtimeBooksCore.EPUBParsing` (Foundation-only
/// and unit-tested). Reading order comes from the OPF spine.
struct EPUBExtractor: TextExtractor {
    var supportedExtensions: [String] { ["epub"] }

    func extract(from url: URL) async throws -> ExtractedDocument {
        let root = try ZipUnpack.toTemporaryDirectory(zipAt: url)
        defer { try? FileManager.default.removeItem(at: root) }

        // 1. container.xml → OPF path
        guard let containerXML = ZipUnpack.readText(root, "META-INF/container.xml"),
              let opfPath = EPUBParsing.opfPath(fromContainerXML: containerXML),
              let opfXML = ZipUnpack.readText(root, opfPath) else {
            throw NoExtractableTextError(filename: url.lastPathComponent)
        }

        // 2. OPF → title + spine order
        let manifest = EPUBParsing.parseOPF(opfXML, opfPath: opfPath)

        // 3. Each spine XHTML → a chapter
        var chapters: [RawChapter] = []
        for href in manifest.spineHrefs {
            guard let xhtml = ZipUnpack.readText(root, href) else { continue }
            let chapter = EPUBParsing.chapter(fromXHTML: xhtml)
            if !chapter.isEmpty { chapters.append(chapter) }
        }

        guard !chapters.isEmpty else { throw NoExtractableTextError(filename: url.lastPathComponent) }
        let title = manifest.title ?? url.deletingPathExtension().lastPathComponent
        return ExtractedDocument(title: title, chapters: chapters)
    }
}

/// DOCX extraction: a `.docx` is a ZIP whose `word/document.xml` holds the body.
struct DOCXExtractor: TextExtractor {
    var supportedExtensions: [String] { ["docx"] }

    func extract(from url: URL) async throws -> ExtractedDocument {
        let root = try ZipUnpack.toTemporaryDirectory(zipAt: url)
        defer { try? FileManager.default.removeItem(at: root) }

        guard let documentXML = ZipUnpack.readText(root, "word/document.xml") else {
            throw NoExtractableTextError(filename: url.lastPathComponent)
        }
        let chapters = DOCXParsing.chapters(fromDocumentXML: documentXML).filter { !$0.isEmpty }
        guard !chapters.isEmpty else { throw NoExtractableTextError(filename: url.lastPathComponent) }
        let title = url.deletingPathExtension().lastPathComponent
        return ExtractedDocument(title: title, chapters: chapters)
    }
}

/// Small helper around ZIPFoundation's `FileManager.unzipItem` (stable across
/// ZIPFoundation versions, unlike the `Archive(...)` initializer which has
/// shifted between failable and throwing forms).
enum ZipUnpack {
    static func toTemporaryDirectory(zipAt url: URL) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: url, to: dir)
        return dir
    }

    /// Reads a file (relative path within the unzipped tree) as text, tolerating
    /// UTF-8/UTF-16/Latin-1 encodings.
    static func readText(_ root: URL, _ relativePath: String) -> String? {
        let fileURL = root.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        for enc: String.Encoding in [.utf8, .utf16, .isoLatin1] {
            if let s = String(data: data, encoding: enc) { return s }
        }
        return nil
    }
}
