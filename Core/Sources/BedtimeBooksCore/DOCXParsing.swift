import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Foundation-only DOCX parsing. A `.docx` is a ZIP whose `word/document.xml`
/// holds the body: `<w:p>` paragraphs containing `<w:t>` text runs, with
/// `<w:pStyle w:val="Heading1">` marking headings. The app layer unzips and
/// passes the document XML here.
public enum DOCXParsing {

    /// Parses `document.xml` into chapters. Paragraphs styled Heading1/Heading2
    /// start a new chapter (and become its title); other paragraphs append to
    /// the current chapter body. Content before the first heading becomes an
    /// untitled leading chapter.
    public static func chapters(fromDocumentXML xml: String) -> [RawChapter] {
        let delegate = DocxDelegate()
        guard let data = xml.data(using: .utf8) else { return [] }
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.parse()
        return delegate.finish()
    }
}

private final class DocxDelegate: NSObject, XMLParserDelegate {
    private var chapters: [RawChapter] = []
    private var currentTitle: String?
    private var currentBody: [String] = []

    // Per-paragraph state.
    private var inParagraph = false
    private var paragraphText = ""
    private var paragraphHeadingLevel: Int?   // 1 or 2 when a heading style is seen
    private var inTextRun = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        let name = elementName
        switch name {
        case "w:p":
            inParagraph = true
            paragraphText = ""
            paragraphHeadingLevel = nil
        case "w:t":
            inTextRun = true
        case "w:pStyle":
            if let val = attributeDict["w:val"] {
                paragraphHeadingLevel = Self.headingLevel(from: val)
            }
        case "w:br", "w:cr":
            if inParagraph { paragraphText += "\n" }
        case "w:tab":
            if inParagraph { paragraphText += "\t" }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTextRun { paragraphText += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName
        switch name {
        case "w:t":
            inTextRun = false
        case "w:p":
            commitParagraph()
            inParagraph = false
        default:
            break
        }
    }

    private func commitParagraph() {
        let trimmed = paragraphText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let level = paragraphHeadingLevel, level <= 2, !trimmed.isEmpty {
            // Start a new chapter at this heading.
            flushChapter()
            currentTitle = trimmed
        } else if !trimmed.isEmpty {
            currentBody.append(trimmed)
        }
    }

    private func flushChapter() {
        let body = currentBody.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if currentTitle != nil || !body.isEmpty {
            let text = body.isEmpty ? (currentTitle ?? "") : body
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                chapters.append(RawChapter(title: currentTitle, text: text))
            }
        }
        currentTitle = nil
        currentBody = []
    }

    func finish() -> [RawChapter] {
        flushChapter()
        return chapters
    }

    /// Maps a paragraph style value to a heading level. Word uses `Heading1`,
    /// `Heading2`, … (and sometimes `Title`).
    static func headingLevel(from style: String) -> Int? {
        let lower = style.lowercased()
        if lower == "title" { return 1 }
        guard lower.hasPrefix("heading") else { return nil }
        let suffix = lower.dropFirst("heading".count)
        return Int(suffix)
    }
}
