import Foundation

/// Splits a block of text into sentences. Abstracted so the iOS app can plug in
/// a `NaturalLanguage.NLTokenizer`-backed implementation (best quality) while
/// Core ships a portable, dependency-free default that runs anywhere — and is
/// what the unit tests exercise.
public protocol SentenceTokenizer: Sendable {
    /// Returns the sentences in `text`, trimmed, in order, with empties removed.
    func sentences(in text: String) -> [String]
}

/// A regex-free, ICU-free sentence splitter: breaks after `.`, `!`, `?`, `…`
/// when followed by whitespace, while leaving common abbreviations and decimal
/// numbers reasonably intact. Good enough for chunking; the app overrides it
/// with `NLTokenizer` for production-quality boundaries.
public struct DefaultSentenceTokenizer: SentenceTokenizer {
    private static let terminators: Set<Character> = [".", "!", "?", "…"]
    private static let closers: Set<Character> = ["\"", "'", "”", "’", ")", "]"]

    public init() {}

    public func sentences(in text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            current.append(c)
            if Self.terminators.contains(c) {
                // Absorb trailing closing quotes/brackets into this sentence.
                var j = i + 1
                while j < chars.count, Self.closers.contains(chars[j]) {
                    current.append(chars[j]); j += 1
                }
                // A real boundary requires whitespace (or end of text) next.
                let atEnd = j >= chars.count
                let nextIsSpace = !atEnd && chars[j].isWhitespace
                if atEnd || nextIsSpace {
                    let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { result.append(trimmed) }
                    current = ""
                    i = j
                    continue
                }
                i = j
                continue
            }
            i += 1
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { result.append(tail) }
        return result
    }
}

/// A run of text to hand to the TTS engine as one synthesis call, tagged with
/// whether it begins a new paragraph (so the conversion stage can insert a
/// slightly longer pause for natural pacing).
public struct TextSegment: Equatable, Sendable {
    public var text: String
    public var startsParagraph: Bool

    public init(text: String, startsParagraph: Bool) {
        self.text = text
        self.startsParagraph = startsParagraph
    }
}

/// Turns a chapter's plain text into TTS-sized segments: paragraphs are split
/// into sentences, then sentences are greedily packed up to `maxCharacters` so
/// the engine receives natural phrase lengths without long stalls. A single
/// sentence longer than the limit becomes its own (possibly hard-wrapped)
/// segment rather than being dropped.
public struct TextChunker: Sendable {
    public let maxCharacters: Int
    private let tokenizer: SentenceTokenizer

    public init(maxCharacters: Int = 400, tokenizer: SentenceTokenizer = DefaultSentenceTokenizer()) {
        precondition(maxCharacters > 0, "maxCharacters must be positive")
        self.maxCharacters = maxCharacters
        self.tokenizer = tokenizer
    }

    public func segments(for chapterText: String) -> [TextSegment] {
        let paragraphs = Self.paragraphs(in: chapterText)
        var segments: [TextSegment] = []

        for paragraph in paragraphs {
            var isFirstSegmentOfParagraph = true
            var buffer = ""

            func flush() {
                let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    segments.append(TextSegment(text: trimmed, startsParagraph: isFirstSegmentOfParagraph))
                    isFirstSegmentOfParagraph = false
                }
                buffer = ""
            }

            for sentence in tokenizer.sentences(in: paragraph) {
                if sentence.count > maxCharacters {
                    flush()
                    for piece in Self.hardWrap(sentence, limit: maxCharacters) {
                        segments.append(TextSegment(text: piece, startsParagraph: isFirstSegmentOfParagraph))
                        isFirstSegmentOfParagraph = false
                    }
                    continue
                }
                let candidateCount = buffer.isEmpty ? sentence.count : buffer.count + 1 + sentence.count
                if candidateCount > maxCharacters {
                    flush()
                }
                buffer += buffer.isEmpty ? sentence : " " + sentence
            }
            flush()
        }
        return segments
    }

    /// Paragraphs are separated by one or more blank lines.
    static func paragraphs(in text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Splits an over-long sentence on word boundaries so no piece exceeds the
    /// limit (a single word longer than the limit is emitted whole).
    static func hardWrap(_ sentence: String, limit: Int) -> [String] {
        var pieces: [String] = []
        var buffer = ""
        for word in sentence.split(separator: " ", omittingEmptySubsequences: true) {
            let candidate = buffer.isEmpty ? String(word) : buffer + " " + word
            if candidate.count > limit, !buffer.isEmpty {
                pieces.append(buffer)
                buffer = String(word)
            } else {
                buffer = candidate
            }
        }
        if !buffer.isEmpty { pieces.append(buffer) }
        return pieces
    }
}
