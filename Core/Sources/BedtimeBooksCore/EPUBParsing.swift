import Foundation
#if canImport(FoundationXML)
import FoundationXML   // XMLParser lives here on non-Apple platforms (Linux)
#endif

/// Foundation-only EPUB parsing. An EPUB is a ZIP of XHTML; the app layer
/// unzips (ZIPFoundation) and hands the raw XML strings here, so all the fiddly
/// parsing is testable without Xcode or third-party packages.
///
/// Pipeline mirrors the EPUB spec:
///   META-INF/container.xml → OPF path → OPF (title + spine order) → XHTML files.
public enum EPUBParsing {

    /// Reads `META-INF/container.xml` and returns the OPF rootfile path
    /// (e.g. "OEBPS/content.opf"), or nil if absent.
    public static func opfPath(fromContainerXML xml: String) -> String? {
        let collector = AttributeCollector(targetElement: "rootfile", attribute: "full-path")
        parse(xml, with: collector)
        return collector.value
    }

    /// The reading order + title pulled from the OPF package document.
    public struct OPFManifest: Equatable, Sendable {
        public var title: String?
        /// Spine document hrefs, in reading order, resolved relative to the OPF
        /// directory (so they match ZIP entry paths).
        public var spineHrefs: [String]
    }

    /// Parses the OPF package document. `opfPath` is the OPF's own path, used to
    /// resolve manifest hrefs against the OPF directory.
    public static func parseOPF(_ xml: String, opfPath: String) -> OPFManifest {
        let delegate = OPFDelegate()
        parse(xml, with: delegate)

        let baseDir = (opfPath as NSString).deletingLastPathComponent
        let ordered = delegate.spineIDRefs.compactMap { idref -> String? in
            guard let href = delegate.manifestHrefByID[idref] else { return nil }
            return resolve(href, relativeTo: baseDir)
        }
        return OPFManifest(title: delegate.title, spineHrefs: ordered)
    }

    /// Turns one XHTML document into a chapter: visible text plus the first
    /// `<h1>`/`<h2>` as the title. Block elements become paragraph breaks.
    public static func chapter(fromXHTML xhtml: String) -> RawChapter {
        let delegate = XHTMLDelegate()
        parse(xhtml, with: delegate)
        let cleaned = normalizeWhitespace(delegate.text)
        return RawChapter(title: delegate.title, text: cleaned)
    }

    // MARK: Helpers

    static func resolve(_ href: String, relativeTo baseDir: String) -> String {
        let decoded = href.removingPercentEncoding ?? href
        if baseDir.isEmpty { return decoded }
        return (baseDir as NSString).appendingPathComponent(decoded)
    }

    static func normalizeWhitespace(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        // Collapse runs of blank lines to a single blank line (paragraph break).
        var out: [String] = []
        var lastBlank = false
        for line in lines {
            let blank = line.isEmpty
            if blank && lastBlank { continue }
            out.append(line)
            lastBlank = blank
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parse(_ xml: String, with delegate: XMLParserDelegate) {
        guard let data = xml.data(using: .utf8) else { return }
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false   // keep qualified names like "dc:title"
        parser.parse()
    }
}

// MARK: - XMLParser delegates

/// Grabs the first occurrence of `attribute` on `targetElement`.
private final class AttributeCollector: NSObject, XMLParserDelegate {
    let targetElement: String
    let attribute: String
    var value: String?

    init(targetElement: String, attribute: String) {
        self.targetElement = targetElement
        self.attribute = attribute
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        guard value == nil else { return }
        // Namespace processing is off, so elementName carries the qualified tag.
        if elementName.caseInsensitiveCompare(targetElement) == .orderedSame {
            value = attributeDict[attribute]
        }
    }
}

/// Collects OPF title, manifest (id → href), and spine order (idrefs).
private final class OPFDelegate: NSObject, XMLParserDelegate {
    var title: String?
    var manifestHrefByID: [String: String] = [:]
    var spineIDRefs: [String] = []

    private var capturingTitle = false
    private var titleBuffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        let name = elementName.lowercased()
        switch name {
        case "dc:title", "title":
            if title == nil { capturingTitle = true; titleBuffer = "" }
        case "item":
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                manifestHrefByID[id] = href
            }
        case "itemref":
            if let idref = attributeDict["idref"] { spineIDRefs.append(idref) }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturingTitle { titleBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if name == "dc:title" || name == "title", capturingTitle {
            let t = titleBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            title = t.isEmpty ? nil : t
            capturingTitle = false
        }
    }
}

/// Extracts readable text from XHTML, inserting paragraph breaks on block-level
/// elements and capturing the first heading as a title.
private final class XHTMLDelegate: NSObject, XMLParserDelegate {
    var text = ""
    var title: String?

    private let blockTags: Set<String> = [
        "p", "div", "br", "li", "tr", "section", "article", "blockquote",
        "h1", "h2", "h3", "h4", "h5", "h6",
    ]
    private let skipTags: Set<String> = ["script", "style", "head"]
    private var skipDepth = 0
    private var inHeading = false
    private var headingBuffer = ""

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String]) {
        let name = elementName.lowercased()
        if skipTags.contains(name) { skipDepth += 1 }
        if (name == "h1" || name == "h2"), title == nil {
            inHeading = true; headingBuffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard skipDepth == 0 else { return }
        text += string
        if inHeading { headingBuffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if skipTags.contains(name), skipDepth > 0 { skipDepth -= 1 }
        if blockTags.contains(name) { text += "\n\n" }
        if (name == "h1" || name == "h2"), inHeading {
            let t = headingBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { title = t }
            inHeading = false
        }
    }
}
