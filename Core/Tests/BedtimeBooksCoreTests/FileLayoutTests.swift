import XCTest
@testable import BedtimeBooksCore

final class FileLayoutTests: XCTestCase {
    let bookID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    func testRelativePaths() {
        let layout = FileLayout(baseURL: URL(fileURLWithPath: "/base"))
        XCTAssertEqual(layout.bookDirectory(bookID), "Books/11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(layout.sourceFile(bookID: bookID, fileExtension: "epub"),
                       "Books/11111111-2222-3333-4444-555555555555/source.epub")
        XCTAssertEqual(layout.audioDirectory(bookID: bookID),
                       "Books/11111111-2222-3333-4444-555555555555/audio")
    }

    func testChapterAudioIsZeroPaddedForSortOrder() {
        let layout = FileLayout(baseURL: URL(fileURLWithPath: "/base"))
        XCTAssertEqual(layout.chapterAudio(bookID: bookID, chapterIndex: 7),
                       "Books/11111111-2222-3333-4444-555555555555/audio/chapter_007.m4a")
        XCTAssertEqual(layout.chapterAudio(bookID: bookID, chapterIndex: 123),
                       "Books/11111111-2222-3333-4444-555555555555/audio/chapter_123.m4a")
    }

    func testExtensionNormalization() {
        XCTAssertEqual(FileLayout.normalizedExtension("TXT"), ".txt")
        XCTAssertEqual(FileLayout.normalizedExtension(".PDF"), ".pdf")
        XCTAssertEqual(FileLayout.normalizedExtension(""), "")
        XCTAssertEqual(FileLayout.normalizedExtension("  "), "")
    }

    func testResolutionAgainstBase() {
        let layout = FileLayout(baseURL: URL(fileURLWithPath: "/var/app/Application Support"))
        let url = layout.url(for: layout.chapterAudio(bookID: bookID, chapterIndex: 0))
        XCTAssertTrue(url.path.hasSuffix("audio/chapter_000.m4a"))
        XCTAssertTrue(url.path.hasPrefix("/var/app/Application Support"))
    }
}
