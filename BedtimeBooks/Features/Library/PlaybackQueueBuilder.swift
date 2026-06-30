import Foundation

/// Builds a `PlaybackQueue` from a converted `Book`, resolving each chapter's
/// stored relative audio path against the runtime storage base.
enum PlaybackQueueBuilder {
    static func makeQueue(for book: Book, storage: StorageService) -> PlaybackQueue? {
        let items: [PlaybackItem] = book.orderedChapters.compactMap { chapter in
            guard chapter.isSynthesized, let rel = chapter.audioRelativePath else { return nil }
            return PlaybackItem(
                id: chapter.index,
                title: chapter.displayTitle,
                url: storage.absoluteURL(forRelativePath: rel),
                duration: chapter.duration)
        }
        guard !items.isEmpty else { return nil }

        let startIndex = items.firstIndex(where: { $0.id == book.lastPlayedChapterIndex }) ?? 0
        let startPosition = book.chapters.first(where: { $0.index == book.lastPlayedChapterIndex })?.positionInChapter ?? 0

        return PlaybackQueue(
            bookID: book.id,
            bookTitle: book.title,
            author: book.author,
            items: items,
            startIndex: startIndex,
            startPosition: startPosition)
    }
}
