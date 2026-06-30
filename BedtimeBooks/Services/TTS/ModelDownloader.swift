import Foundation
import ZIPFoundation
import Observation
import BedtimeBooksCore

/// Downloads and installs neural voice models on first use, so the app binary
/// stays small and the (large) Kokoro model is fetched once over Wi-Fi and then
/// used fully offline. Install state is derived from disk — no extra database.
///
/// A voice's `resourceReference` (from voices.json) is the URL of a `.zip`
/// containing the sherpa-onnx Kokoro files laid out as:
///   model.onnx · voices.bin · tokens.txt · espeak-ng-data/
/// The zip is unpacked into `Models/<voiceID>/` (see `FileLayout`).
@MainActor
@Observable
final class ModelDownloader {
    enum Status: Equatable {
        case notInstalled
        case downloading(Double)   // 0...1
        case installing
        case installed
        case failed(String)
    }

    enum ModelError: LocalizedError {
        case noSource
        case incompleteArchive
        var errorDescription: String? {
            switch self {
            case .noSource: return "This voice has no download configured."
            case .incompleteArchive: return "The downloaded voice files were incomplete."
            }
        }
    }

    private(set) var statuses: [String: Status] = [:]
    @ObservationIgnored private let storage: StorageService
    @ObservationIgnored private let fileManager = FileManager.default

    init(storage: StorageService) {
        self.storage = storage
    }

    // MARK: Query

    func modelDirectory(for voiceID: String) -> URL {
        storage.absoluteURL(forRelativePath: storage.layout.voiceModelDirectory(voiceID: voiceID))
    }

    func isInstalled(_ voiceID: String) -> Bool {
        let model = modelDirectory(for: voiceID).appendingPathComponent("model.onnx")
        return fileManager.fileExists(atPath: model.path)
    }

    func status(for voiceID: String) -> Status {
        if let s = statuses[voiceID] { return s }
        return isInstalled(voiceID) ? .installed : .notInstalled
    }

    // MARK: Install

    /// Ensures the model for a neural voice is present, downloading if needed.
    /// No-op for system voices and for already-installed models. `onProgress`
    /// reports download fraction (0...1) for UI.
    func ensureInstalled(_ voice: VoiceDescriptor, onProgress: ((Double) -> Void)? = nil) async throws {
        guard voice.kind == .neural else { return }
        if isInstalled(voice.id) { statuses[voice.id] = .installed; return }
        guard voice.source == .download,
              let ref = voice.resourceReference, let url = URL(string: ref) else {
            // On-Demand Resources path would go here; for now only HTTPS zips.
            throw ModelError.noSource
        }
        try await download(voice: voice, from: url, onProgress: onProgress)
    }

    private func download(voice: VoiceDescriptor, from url: URL, onProgress: ((Double) -> Void)?) async throws {
        statuses[voice.id] = .downloading(0)
        do {
            let progress = ProgressReporter { [weak self] fraction in
                self?.statuses[voice.id] = .downloading(fraction)
                onProgress?(fraction)
            }
            let zipURL = try await FileDownload.run(from: url, progress: progress)
            defer { try? fileManager.removeItem(at: zipURL) }

            statuses[voice.id] = .installing
            let dir = modelDirectory(for: voice.id)
            try? fileManager.removeItem(at: dir)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            try fileManager.unzipItem(at: zipURL, to: dir)
            try normalizeLayout(in: dir)

            guard isInstalled(voice.id) else { throw ModelError.incompleteArchive }
            statuses[voice.id] = .installed
        } catch {
            statuses[voice.id] = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            throw error
        }
    }

    /// If the zip wrapped everything in a single top-level folder, hoist its
    /// contents up so `model.onnx` sits directly in `Models/<voiceID>/`.
    private func normalizeLayout(in dir: URL) throws {
        if fileManager.fileExists(atPath: dir.appendingPathComponent("model.onnx").path) { return }
        let entries = (try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let subdirs = entries.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        guard subdirs.count == 1, let inner = subdirs.first else { return }
        for item in (try? fileManager.contentsOfDirectory(at: inner, includingPropertiesForKeys: nil)) ?? [] {
            try fileManager.moveItem(at: item, to: dir.appendingPathComponent(item.lastPathComponent))
        }
        try? fileManager.removeItem(at: inner)
    }
}

/// Main-actor-hopping progress sink so the URLSession delegate (background
/// queue) can update the observable status safely.
private final class ProgressReporter: @unchecked Sendable {
    private let onProgress: (Double) -> Void
    init(_ onProgress: @escaping (Double) -> Void) { self.onProgress = onProgress }
    func report(_ fraction: Double) {
        Task { @MainActor in self.onProgress(fraction) }
    }
}

/// One-shot resumable-friendly file download with progress, bridged to async.
private enum FileDownload {
    static func run(from url: URL, progress: ProgressReporter) async throws -> URL {
        let delegate = Delegate(progress: progress)
        return try await withCheckedThrowingContinuation { cont in
            delegate.continuation = cont
            let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
            session.downloadTask(with: url).resume()
        }
    }

    private final class Delegate: NSObject, URLSessionDownloadDelegate {
        var continuation: CheckedContinuation<URL, Error>?
        private let progress: ProgressReporter
        init(progress: ProgressReporter) { self.progress = progress }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                        totalBytesExpectedToWrite: Int64) {
            if totalBytesExpectedToWrite > 0 {
                progress.report(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
            }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didFinishDownloadingTo location: URL) {
            // The temp file is deleted when this returns, so move it now.
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
            do {
                try FileManager.default.moveItem(at: location, to: dest)
                continuation?.resume(returning: dest)
            } catch {
                continuation?.resume(throwing: error)
            }
            continuation = nil
            session.invalidateAndCancel()
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error {
                continuation?.resume(throwing: error)
                continuation = nil
            }
            session.invalidateAndCancel()
        }
    }
}
