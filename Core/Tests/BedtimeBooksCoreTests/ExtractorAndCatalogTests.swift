import XCTest
@testable import BedtimeBooksCore

final class ExtractorAndCatalogTests: XCTestCase {

    private func writeTemp(_ contents: String, ext: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("bbtest-\(UUID().uuidString).\(ext)")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testPlainTextSingleChapter() async throws {
        let url = try writeTemp("Once upon a time.\nThe end.", ext: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = try await PlainTextExtractor().extract(from: url)
        XCTAssertEqual(doc.chapters.count, 1)
        XCTAssertTrue(doc.chapters[0].text.contains("Once upon a time"))
    }

    func testPlainTextSplitsOnBigGaps() async throws {
        let url = try writeTemp("Chapter one body.\n\n\nChapter two body.", ext: "txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = try await PlainTextExtractor().extract(from: url)
        XCTAssertEqual(doc.chapters.count, 2)
    }

    func testMarkdownHeadingsBecomeChapters() {
        let md = """
        # The Sleepy Dragon
        Once there was a dragon.

        ## Night falls
        The dragon yawned **loudly**.
        """
        let doc = MarkdownExtractor.parse(md)
        XCTAssertEqual(doc.chapters.count, 2)
        XCTAssertEqual(doc.chapters[0].title, "The Sleepy Dragon")
        XCTAssertEqual(doc.chapters[1].title, "Night falls")
        // Inline emphasis markers stripped.
        XCTAssertTrue(doc.chapters[1].text.contains("loudly"))
        XCTAssertFalse(doc.chapters[1].text.contains("**"))
    }

    func testMarkdownLinkKeepsVisibleText() {
        XCTAssertEqual(MarkdownExtractor.stripInline("See [the moon](http://x)"), "See the moon")
    }

    func testVoiceCatalogDecodesAndFindsDefault() throws {
        let json = """
        {
          "defaultVoiceID": "kokoro-af-heart",
          "voices": [
            { "id": "system-en", "displayName": "Built-in Voice", "kind": "system",
              "localeIdentifier": "en-US", "blurb": "Always available", "source": "none" },
            { "id": "kokoro-af-heart", "displayName": "Heart", "kind": "neural",
              "localeIdentifier": "en-US", "blurb": "Warm female", "source": "onDemandResource",
              "speakerID": 0, "resourceReference": "kokoro-en", "approxSizeMB": 90,
              "license": "Apache-2.0", "attribution": "Kokoro-82M" }
          ]
        }
        """
        let catalog = try VoiceCatalog.decode(from: Data(json.utf8))
        XCTAssertEqual(catalog.voices.count, 2)
        XCTAssertEqual(catalog.defaultVoice?.displayName, "Heart")
        XCTAssertEqual(catalog.voice(withID: "system-en")?.kind, .system)
        XCTAssertEqual(catalog.defaultVoice?.license, "Apache-2.0")
    }
}
