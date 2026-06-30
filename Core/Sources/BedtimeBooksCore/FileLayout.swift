import Foundation

/// Centralizes the on-disk layout for everything the app stores, and — crucially
/// — works in **relative** paths. iOS rewrites the app container's absolute path
/// between installs/launches, so we persist relative paths in SwiftData and
/// resolve them against a freshly-resolved base directory at runtime.
///
/// Layout (rooted at Application Support):
/// ```
/// Models/<voiceID>/{model.onnx, voices.bin, tokens.txt, espeak-ng-data/}
/// Books/<bookUUID>/source.<ext>
/// Books/<bookUUID>/cover.jpg
/// Books/<bookUUID>/audio/chapter_000.m4a
/// ```
public struct FileLayout: Sendable {
    /// Absolute base directory (Application Support) resolved at runtime.
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    // MARK: Relative paths (these are what get persisted)

    public func bookDirectory(_ bookID: UUID) -> String {
        "Books/\(bookID.uuidString)"
    }

    public func sourceFile(bookID: UUID, fileExtension: String) -> String {
        let ext = Self.normalizedExtension(fileExtension)
        return "\(bookDirectory(bookID))/source\(ext)"
    }

    public func coverImage(bookID: UUID) -> String {
        "\(bookDirectory(bookID))/cover.jpg"
    }

    public func audioDirectory(bookID: UUID) -> String {
        "\(bookDirectory(bookID))/audio"
    }

    /// Zero-padded chapter filename, e.g. `chapter_007.m4a`, so directory
    /// listings sort in playback order.
    public func chapterAudio(bookID: UUID, chapterIndex: Int, fileExtension: String = "m4a") -> String {
        let padded = String(format: "%03d", chapterIndex)
        let ext = Self.normalizedExtension(fileExtension)
        return "\(audioDirectory(bookID))/chapter_\(padded)\(ext)"
    }

    public func voiceModelDirectory(voiceID: String) -> String {
        "Models/\(voiceID)"
    }

    // MARK: Resolution

    /// Resolves a stored relative path against the current base directory.
    public func url(for relativePath: String) -> URL {
        baseURL.appendingPathComponent(relativePath)
    }

    // MARK: Helpers

    /// Normalizes a user/UTType-supplied extension to a leading-dot form, or
    /// empty string when there is none. Accepts `"txt"`, `".txt"`, `"TXT"`.
    static func normalizedExtension(_ ext: String) -> String {
        let trimmed = ext.trimmingCharacters(in: CharacterSet(charactersIn: ". ")).lowercased()
        return trimmed.isEmpty ? "" : ".\(trimmed)"
    }
}
