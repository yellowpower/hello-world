import Foundation
import ZIPFoundation
import BedtimeBooksCore

/// EPUB extraction: an `.epub` is a ZIP of XHTML. We unzip with ZIPFoundation
/// and delegate all XML parsing to `BedtimeBooksCore.EPUBParsing` (which is
/// Foundation-only and unit-tested). Reading order comes from the OPF spine.
struct EPUBExtractor: TextExtractor {
    var supportedExtensions: [String] { ["epub"] }

    func extract(from url: URL) async throws -> ExtractedDocument {
        guard let archive = Archive(url: url, accessMode: .read) else {
            throw NoExtractableTextError(filename: url.lastPathComponent)
        }
        // 1. container.xml → OPF path
        guard let containerXML = Self.readEntry(archive, path: "META-INF/container.xml"),
              let opfPath = EPUBParsing.opfPath(fromContainerXML: containerXML),
              let opfXML = Self.readEntry(archive, path: opfPath) else {
            throw NoExtractableTextError(filename: url.lastPathComponent)
        }

        // 2. OPF → title + spine order
        let manifest = EPUBParsing.parseOPF(opfXML, opfPath: opfPath)

        // 3. Each spine XHTML → a chapter
        var chapters: [RawChapter] = []
        for href in manifest.spineHrefs {
            guard let xhtml = Self.readEntry(archive, path: href) else { continue }
            let chapter = EPUBParsing.chapter(fromXHTML: xhtml)
            if !chapter.isEmpty { chapters.append(chapter) }
        }

        guard !chapters.isEmpty else { throw NoExtractableTextError(filename: url.lastPathComponent) }
        let title = manifest.title ?? url.deletingPathExtension().lastPathComponent
        return ExtractedDocument(title: title, chapters: chapters)
    }

    /// Reads a ZIP entry fully into memory (EPUB chapter files are small).
    static func readEntry(_ archive: Archive, path: String) -> String? {
        guard let entry = archive[path] else { return nil }
        var data = Data()
        do {
            _ = try archive.extract(entry) { data.append($0) }
        } catch {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

/// DOCX extraction: a `.docx` is a ZIP whose `word/document.xml` holds the body.
/// Unzip with ZIPFoundation, parse with `BedtimeBooksCore.DOCXParsing`.
struct DOCXExtractor: TextExtractor {
    var supportedExtensions: [String] { ["docx"] }

    func extract(from url: URL) async throws -> ExtractedDocument {
        guard let archive = Archive(url: url, accessMode: .read),
              let documentXML = EPUBExtractor.readEntry(archive, path: "word/document.xml") else {
            throw NoExtractableTextError(filename: url.lastPathComponent)
        }
        let chapters = DOCXParsing.chapters(fromDocumentXML: documentXML).filter { !$0.isEmpty }
        guard !chapters.isEmpty else { throw NoExtractableTextError(filename: url.lastPathComponent) }
        let title = url.deletingPathExtension().lastPathComponent
        return ExtractedDocument(title: title, chapters: chapters)
    }
}
