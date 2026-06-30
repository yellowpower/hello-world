import XCTest
import SwiftData
@testable import BedtimeBooks

/// App-target smoke tests. These run on the iOS simulator (they touch
/// SwiftData). Pure logic lives in BedtimeBooksCore's own test suite, which can
/// run anywhere with `swift test`.
final class PlaybackQueueTests: XCTestCase {

    @MainActor
    func testQueueSkipsUnsynthesizedChaptersAndResumesAtLastPlayed() throws {
        // In-memory SwiftData store.
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Book.self, Chapter.self, configurations: config)
        let context = ModelContext(container)

        let book = Book(title: "Test", sourceFilename: "test.txt", voiceID: "system-en")
        context.insert(book)

        let c0 = Chapter(index: 0, title: "One", text: "a")
        c0.isSynthesized = true; c0.audioRelativePath = "Books/x/audio/chapter_000.m4a"; c0.duration = 30
        let c1 = Chapter(index: 1, title: "Two", text: "b") // not synthesized
        let c2 = Chapter(index: 2, title: "Three", text: "c")
        c2.isSynthesized = true; c2.audioRelativePath = "Books/x/audio/chapter_002.m4a"; c2.duration = 45
        c2.positionInChapter = 12
        for c in [c0, c1, c2] { c.book = book; book.chapters.append(c); context.insert(c) }
        book.lastPlayedChapterIndex = 2

        let storage = try StorageService()
        let queue = try XCTUnwrap(PlaybackQueueBuilder.makeQueue(for: book, storage: storage))

        // Only the two synthesized chapters appear.
        XCTAssertEqual(queue.items.map(\.id), [0, 2])
        // Resume points at the last played chapter and its saved offset.
        XCTAssertEqual(queue.startIndex, 1) // index within items array (chapter id 2)
        XCTAssertEqual(queue.startPosition, 12)
    }
}
