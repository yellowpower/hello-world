import Foundation
import BedtimeBooksCore

/// Picks the right `TextExtractor` for an imported file by its extension and
/// runs it. New formats are added by registering another extractor.
struct TextExtractorRegistry {
    private let extractors: [TextExtractor]

    init(extractors: [TextExtractor]) {
        self.extractors = extractors
    }

    /// The default set wired into the app. TXT/MD/PDF are live in M1; EPUB and
    /// DOCX are registered as stubs until M3.
    static func makeDefault() -> TextExtractorRegistry {
        TextExtractorRegistry(extractors: [
            PlainTextExtractor(),
            MarkdownExtractor(),
            PDFExtractor(),
            EPUBExtractor(),
            DOCXExtractor(),
        ])
    }

    /// All file extensions the app advertises support for (for the importer).
    var supportedExtensions: [String] {
        extractors.flatMap { $0.supportedExtensions }
    }

    func extractor(for url: URL) -> TextExtractor? {
        let ext = url.pathExtension.lowercased()
        return extractors.first { $0.supportedExtensions.contains(ext) }
    }

    func extract(from url: URL) async throws -> ExtractedDocument {
        guard let extractor = extractor(for: url) else {
            throw UnsupportedFormatError(fileExtension: url.pathExtension)
        }
        return try await extractor.extract(from: url)
    }
}

struct UnsupportedFormatError: LocalizedError {
    let fileExtension: String
    var errorDescription: String? {
        "“.\(fileExtension)” files aren't supported yet."
    }
}
