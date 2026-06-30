import Foundation
import BedtimeBooksCore

/// Owns the app's on-disk storage: resolves the Application Support base
/// directory at runtime and hands out a `FileLayout` for relative-path math.
/// Everything user-generated lives under here and is excluded from iCloud
/// backup (audio is large and regenerable from the source file).
final class StorageService {
    let layout: FileLayout
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        let base = try fileManager
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("BedtimeBooks", isDirectory: true)
        try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        try Self.excludeFromBackup(base)
        self.layout = FileLayout(baseURL: base)
    }

    // MARK: Directory provisioning

    /// Ensures a book's `audio/` directory exists and returns its absolute URL.
    @discardableResult
    func prepareAudioDirectory(bookID: UUID) throws -> URL {
        let url = layout.url(for: layout.audioDirectory(bookID: bookID))
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func absoluteURL(forRelativePath path: String) -> URL {
        layout.url(for: path)
    }

    /// Copies an imported (security-scoped) file into the book's directory and
    /// returns the stored relative path.
    func importSourceFile(from sourceURL: URL, bookID: UUID) throws -> String {
        let ext = sourceURL.pathExtension
        let relative = layout.sourceFile(bookID: bookID, fileExtension: ext)
        let dest = layout.url(for: relative)
        try fileManager.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.copyItem(at: sourceURL, to: dest)
        return relative
    }

    /// Deletes everything stored for a book (audio, source, cover).
    func deleteBookStorage(bookID: UUID) {
        let dir = layout.url(for: layout.bookDirectory(bookID))
        try? fileManager.removeItem(at: dir)
    }

    // MARK: Backup exclusion

    private static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(values)
    }
}
