import Foundation
import BedtimeBooksCore

/// EPUB extraction (M3): unzip the container, read `META-INF/container.xml` to
/// find the OPF, walk the `<spine>` in order, parse each XHTML item with
/// SwiftSoup, and map `<h1>/<h2>` to chapter titles.
///
/// Stubbed until the ZIPFoundation + SwiftSoup integration lands so the app
/// compiles and advertises the format without silently producing empty audio.
struct EPUBExtractor: TextExtractor {
    var supportedExtensions: [String] { ["epub"] }

    func extract(from url: URL) async throws -> ExtractedDocument {
        throw FormatComingSoonError(formatName: "EPUB")
    }
}

/// DOCX extraction (M3): unzip, read `word/document.xml`, gather `<w:t>` runs
/// per `<w:p>`, and map `Heading1/2` paragraph styles to chapter titles.
struct DOCXExtractor: TextExtractor {
    var supportedExtensions: [String] { ["docx"] }

    func extract(from url: URL) async throws -> ExtractedDocument {
        throw FormatComingSoonError(formatName: "Word (.docx)")
    }
}

struct FormatComingSoonError: LocalizedError {
    let formatName: String
    var errorDescription: String? {
        "\(formatName) import is coming soon. For now, try a text, Markdown, or PDF file."
    }
}
