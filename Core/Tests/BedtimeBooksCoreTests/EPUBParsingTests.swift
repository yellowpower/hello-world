import XCTest
@testable import BedtimeBooksCore

final class EPUBParsingTests: XCTestCase {

    func testContainerXMLYieldsOPFPath() {
        let xml = """
        <?xml version="1.0"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        XCTAssertEqual(EPUBParsing.opfPath(fromContainerXML: xml), "OEBPS/content.opf")
    }

    func testOPFTitleAndSpineOrderResolvedRelativeToOPFDir() {
        let opf = """
        <?xml version="1.0"?>
        <package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/">
          <metadata><dc:title>The Sleepy Dragon</dc:title></metadata>
          <manifest>
            <item id="c1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
            <item id="c2" href="chap2.xhtml" media-type="application/xhtml+xml"/>
            <item id="css" href="style.css" media-type="text/css"/>
          </manifest>
          <spine>
            <itemref idref="c1"/>
            <itemref idref="c2"/>
          </spine>
        </package>
        """
        let manifest = EPUBParsing.parseOPF(opf, opfPath: "OEBPS/content.opf")
        XCTAssertEqual(manifest.title, "The Sleepy Dragon")
        XCTAssertEqual(manifest.spineHrefs, ["OEBPS/chap1.xhtml", "OEBPS/chap2.xhtml"])
    }

    func testXHTMLChapterExtractsTitleAndParagraphs() {
        let xhtml = """
        <?xml version="1.0"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
          <head><title>ignored</title><style>p{color:red}</style></head>
          <body>
            <h1>Night Falls</h1>
            <p>The dragon yawned.</p>
            <p>Then it slept.</p>
          </body>
        </html>
        """
        let chapter = EPUBParsing.chapter(fromXHTML: xhtml)
        XCTAssertEqual(chapter.title, "Night Falls")
        XCTAssertTrue(chapter.text.contains("The dragon yawned."))
        XCTAssertTrue(chapter.text.contains("Then it slept."))
        // <style> content must not leak into spoken text.
        XCTAssertFalse(chapter.text.contains("color"))
        // Paragraphs are separated by a blank line.
        XCTAssertTrue(chapter.text.contains("yawned.\n\nThen") || chapter.text.contains("yawned.\n\n  Then"))
    }
}
