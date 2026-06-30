import XCTest
@testable import BedtimeBooksCore

final class TextChunkerTests: XCTestCase {
    func testSentenceSplittingBasic() {
        let t = DefaultSentenceTokenizer()
        let s = t.sentences(in: "Hello there. How are you? I am fine!")
        XCTAssertEqual(s, ["Hello there.", "How are you?", "I am fine!"])
    }

    func testSentenceSplittingKeepsDecimalsAndClosers() {
        let t = DefaultSentenceTokenizer()
        // No whitespace after the dot in 3.14 -> not a boundary.
        XCTAssertEqual(t.sentences(in: "Pi is 3.14 today."), ["Pi is 3.14 today."])
        // Closing quote absorbed into the sentence.
        XCTAssertEqual(t.sentences(in: "\"Run!\" she said."), ["\"Run!\"", "she said."])
    }

    func testPackingStaysUnderLimit() {
        let chunker = TextChunker(maxCharacters: 30)
        let segments = chunker.segments(for: "One two three. Four five six. Seven eight nine.")
        for seg in segments {
            XCTAssertLessThanOrEqual(seg.text.count, 30, "segment exceeded limit: \(seg.text)")
        }
        XCTAssertFalse(segments.isEmpty)
    }

    func testPackingCombinesShortSentences() {
        let chunker = TextChunker(maxCharacters: 400)
        let segments = chunker.segments(for: "A. B. C.")
        // All three short sentences fit in one segment.
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.text, "A. B. C.")
    }

    func testParagraphBoundariesAreMarked() {
        let chunker = TextChunker(maxCharacters: 400)
        let segments = chunker.segments(for: "First para.\n\nSecond para.")
        XCTAssertEqual(segments.count, 2)
        XCTAssertTrue(segments[0].startsParagraph)
        XCTAssertTrue(segments[1].startsParagraph)
    }

    func testOverlongSentenceIsHardWrappedNotDropped() {
        let chunker = TextChunker(maxCharacters: 10)
        let long = "supercalifragilistic expialidocious wordy phrase here"
        let segments = chunker.segments(for: long)
        XCTAssertFalse(segments.isEmpty)
        // The very long first word may exceed the limit on its own, but nothing
        // is lost — concatenated content covers all words.
        let joined = segments.map(\.text).joined(separator: " ")
        for word in long.split(separator: " ") {
            XCTAssertTrue(joined.contains(word), "missing word \(word)")
        }
    }
}
