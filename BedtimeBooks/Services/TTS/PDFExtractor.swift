import Foundation
import PDFKit
import BedtimeBooksCore

/// Extracts text from a PDF using PDFKit. Uses the document outline for chapter
/// boundaries when present; otherwise falls back to a single chapter of the
/// whole document. Image-only/scanned PDFs (no extractable text) surface a
/// `NoExtractableTextError` so the UI can explain why (no OCR in v1).
struct PDFExtractor: TextExtractor {
    var supportedExtensions: [String] { ["pdf"] }

    func extract(from url: URL) async throws -> ExtractedDocument {
        guard let doc = PDFDocument(url: url) else {
            throw NoExtractableTextError(filename: url.lastPathComponent)
        }
        let title = url.deletingPathExtension().lastPathComponent
        let fullText = pageText(of: doc).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullText.isEmpty else { throw NoExtractableTextError(filename: url.lastPathComponent) }

        // For v1 we keep it simple: the whole PDF is one chapter. Outline-based
        // chapter splitting can be layered in later without changing callers.
        return ExtractedDocument(title: title, chapters: [RawChapter(title: nil, text: fullText)])
    }

    private func pageText(of doc: PDFDocument) -> String {
        var parts: [String] = []
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let s = page.string {
                parts.append(s)
            }
        }
        return parts.joined(separator: "\n\n")
    }
}
