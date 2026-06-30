import Foundation
import NaturalLanguage
import BedtimeBooksCore

/// Production sentence splitter backed by Apple's `NaturalLanguage` framework,
/// which understands real linguistic boundaries far better than the portable
/// default in Core. The app injects this into `TextChunker`; Core's tests still
/// use the dependency-free default.
struct NLSentenceTokenizer: SentenceTokenizer {
    func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var result: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = text[range].trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty { result.append(sentence) }
            return true
        }
        return result
    }
}
