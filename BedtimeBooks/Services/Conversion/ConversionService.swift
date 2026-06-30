import Foundation
import AVFoundation
import SwiftData
import BedtimeBooksCore

/// Drives a book from imported source file to a set of playable per-chapter
/// `.m4a` files, reporting progress and honoring cancellation.
///
/// Pipeline: extract text → chunk into segments → synthesize each segment with
/// the chosen `TTSEngine` → write/encode per chapter → update the SwiftData
/// model. Runs off the main actor; SwiftData mutations are hopped back to the
/// model's context owner by the caller via the returned per-chapter results.
@MainActor
final class ConversionService {
    private let storage: StorageService
    private let extractors: TextExtractorRegistry
    private let makeEngine: (Book) -> TTSEngine

    init(storage: StorageService,
         extractors: TextExtractorRegistry,
         makeEngine: @escaping (Book) -> TTSEngine) {
        self.storage = storage
        self.extractors = extractors
        self.makeEngine = makeEngine
    }

    /// Converts `book`, mutating its SwiftData objects as chapters complete and
    /// streaming progress. Cancel by cancelling the consuming `Task`.
    func convert(book: Book, modelContext: ModelContext) -> AsyncStream<ConversionProgress> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                await self.run(book: book, modelContext: modelContext, emit: { continuation.yield($0) })
                continuation.finish()
            }
            continuation.onTermination = { reason in
                if case .cancelled = reason { task.cancel() }
            }
        }
    }

    private func run(book: Book, modelContext: ModelContext, emit: (ConversionProgress) -> Void) async {
        let sourceURL = storage.absoluteURL(forRelativePath:
            storage.layout.sourceFile(bookID: book.id, fileExtension: (book.sourceFilename as NSString).pathExtension))

        do {
            // 1. Extract text.
            book.conversionState = .extracting
            emit(.init(phase: .extracting, chapterCount: 0, completedChapters: 0, fractionComplete: 0))
            let document = try await extractors.extract(from: sourceURL).prunedOfEmptyChapters()
            guard !document.chapters.isEmpty else {
                throw NoExtractableTextError(filename: book.sourceFilename)
            }

            // Sync chapters into the model (replace any stale ones).
            syncChapters(document, into: book, modelContext: modelContext)
            let chapters = book.orderedChapters
            let totalChapters = chapters.count

            // 2. Synthesize + encode each chapter.
            book.conversionState = .converting
            try storage.prepareAudioDirectory(bookID: book.id)
            let engine = makeEngine(book)
            let chunker = TextChunker(maxCharacters: 400, tokenizer: NLSentenceTokenizer())

            for (chapterIndex, chapter) in chapters.enumerated() {
                try Task.checkCancellation()
                let segments = chunker.segments(for: chapter.text)
                let relativePath = storage.layout.chapterAudio(bookID: book.id, chapterIndex: chapter.index)
                let outURL = storage.absoluteURL(forRelativePath: relativePath)
                let writer = ChapterAudioWriter(outputURL: outURL)

                for (segmentIndex, segment) in segments.enumerated() {
                    try Task.checkCancellation()
                    emit(.init(
                        phase: .synthesizing(chapterIndex: chapterIndex, segmentIndex: segmentIndex, segmentCount: segments.count),
                        chapterCount: totalChapters,
                        completedChapters: chapterIndex,
                        fractionComplete: overallFraction(chapterIndex, segmentIndex, segments.count, totalChapters)))

                    // Longer pause between paragraphs, short pause between sentences.
                    if segmentIndex > 0 {
                        try writer.appendSilence(seconds: segment.startsParagraph ? 0.6 : 0.25)
                    }
                    let buffers = try await engine.synthesize(text: segment.text)
                    for buffer in buffers { try writer.append(buffer) }
                }

                emit(.init(phase: .encoding(chapterIndex: chapterIndex),
                           chapterCount: totalChapters, completedChapters: chapterIndex,
                           fractionComplete: overallFraction(chapterIndex, segments.count, segments.count, totalChapters)))
                let duration = writer.finish()
                chapter.audioRelativePath = relativePath
                chapter.duration = duration
                chapter.isSynthesized = true
                try? modelContext.save()
            }

            book.conversionState = .ready
            book.lastErrorMessage = nil
            try? modelContext.save()
            emit(.init(phase: .finished, chapterCount: totalChapters, completedChapters: totalChapters, fractionComplete: 1))
        } catch is CancellationError {
            book.conversionState = .pending
            try? modelContext.save()
            emit(.init(phase: .cancelled, chapterCount: book.chapters.count, completedChapters: 0, fractionComplete: 0))
        } catch {
            book.conversionState = .failed
            book.lastErrorMessage = friendlyMessage(for: error)
            try? modelContext.save()
            emit(.init(phase: .failed(message: book.lastErrorMessage ?? "Conversion failed"),
                       chapterCount: book.chapters.count, completedChapters: 0, fractionComplete: 0))
        }
    }

    // MARK: Helpers

    private func syncChapters(_ document: ExtractedDocument, into book: Book, modelContext: ModelContext) {
        for existing in book.chapters { modelContext.delete(existing) }
        book.chapters = []
        if book.title.trimmingCharacters(in: .whitespaces).isEmpty, !document.title.isEmpty {
            book.title = document.title
        }
        for (i, raw) in document.chapters.enumerated() {
            let chapter = Chapter(index: i, title: raw.title, text: raw.text)
            chapter.book = book
            book.chapters.append(chapter)
            modelContext.insert(chapter)
        }
    }

    private func overallFraction(_ chapterIndex: Int, _ segmentIndex: Int, _ segmentCount: Int, _ totalChapters: Int) -> Double {
        guard totalChapters > 0 else { return 0 }
        let perChapter = 1.0 / Double(totalChapters)
        let withinChapter = segmentCount > 0 ? Double(segmentIndex) / Double(segmentCount) : 0
        return (Double(chapterIndex) + withinChapter) * perChapter
    }

    private func friendlyMessage(for error: Error) -> String {
        if let noText = error as? NoExtractableTextError {
            return "We couldn't find any readable text in “\(noText.filename)”. Scanned or image-only files aren't supported yet."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
