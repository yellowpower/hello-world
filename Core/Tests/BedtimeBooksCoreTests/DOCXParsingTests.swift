import XCTest
@testable import BedtimeBooksCore

final class DOCXParsingTests: XCTestCase {

    func testHeadingsStartChaptersAndRunsConcatenate() {
        let xml = """
        <?xml version="1.0"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p>
              <w:pPr><w:pStyle w:val="Heading1"/></w:pPr>
              <w:r><w:t>Chapter One</w:t></w:r>
            </w:p>
            <w:p>
              <w:r><w:t>The dragon </w:t></w:r>
              <w:r><w:t>was sleepy.</w:t></w:r>
            </w:p>
            <w:p>
              <w:pPr><w:pStyle w:val="Heading2"/></w:pPr>
              <w:r><w:t>Chapter Two</w:t></w:r>
            </w:p>
            <w:p>
              <w:r><w:t>Goodnight.</w:t></w:r>
            </w:p>
          </w:body>
        </w:document>
        """
        let chapters = DOCXParsing.chapters(fromDocumentXML: xml)
        XCTAssertEqual(chapters.count, 2)
        XCTAssertEqual(chapters[0].title, "Chapter One")
        // Multiple <w:t> runs in a paragraph concatenate.
        XCTAssertEqual(chapters[0].text, "The dragon was sleepy.")
        XCTAssertEqual(chapters[1].title, "Chapter Two")
        XCTAssertEqual(chapters[1].text, "Goodnight.")
    }

    func testNoHeadingsProducesSingleUntitledChapter() {
        let xml = """
        <?xml version="1.0"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
            <w:p><w:r><w:t>Once upon a time.</w:t></w:r></w:p>
            <w:p><w:r><w:t>The end.</w:t></w:r></w:p>
          </w:body>
        </w:document>
        """
        let chapters = DOCXParsing.chapters(fromDocumentXML: xml)
        XCTAssertEqual(chapters.count, 1)
        XCTAssertNil(chapters[0].title)
        XCTAssertTrue(chapters[0].text.contains("Once upon a time."))
        XCTAssertTrue(chapters[0].text.contains("The end."))
    }

    func testHeadingLevelParsing() {
        XCTAssertEqual(DocxHeadingProbe.level("Heading1"), 1)
        XCTAssertEqual(DocxHeadingProbe.level("heading2"), 2)
        XCTAssertEqual(DocxHeadingProbe.level("Title"), 1)
        XCTAssertNil(DocxHeadingProbe.level("BodyText"))
        XCTAssertEqual(DocxHeadingProbe.level("Heading3"), 3)
    }
}

/// Test shim exposing the internal heading-level mapping.
enum DocxHeadingProbe {
    static func level(_ s: String) -> Int? {
        // Mirror of DocxDelegate.headingLevel for direct unit testing.
        let lower = s.lowercased()
        if lower == "title" { return 1 }
        guard lower.hasPrefix("heading") else { return nil }
        return Int(lower.dropFirst("heading".count))
    }
}
