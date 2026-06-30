import SwiftUI
import SwiftData
import BedtimeBooksCore

/// Shows live conversion progress for a book and lets the user cancel. Starts
/// automatically when the book isn't ready yet.
struct ConversionView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var fraction: Double = 0
    @State private var statusText: String = "Preparing…"
    @State private var isFailed = false
    @State private var isDone = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: isFailed ? "exclamationmark.triangle.fill" : (isDone ? "checkmark.circle.fill" : "waveform.circle"))
                .font(.system(size: 64))
                .foregroundStyle(isFailed ? .red : (isDone ? .green : .tint))
                .symbolEffect(.pulse, isActive: !isDone && !isFailed)

            Text(book.title).font(.title2.bold()).multilineTextAlignment(.center)

            if !isDone && !isFailed {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 40)
            }
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            if isDone {
                Button("Start Listening") { dismiss() }
                    .buttonStyle(.borderedProminent)
            } else if isFailed {
                VStack(spacing: 12) {
                    Button("Try Again") { start() }
                        .buttonStyle(.borderedProminent)
                    Button("Close", role: .cancel) { dismiss() }
                }
            } else {
                Button("Cancel", role: .cancel) {
                    task?.cancel()
                    dismiss()
                }
            }
            Spacer().frame(height: 20)
        }
        .padding()
        .interactiveDismissDisabled(!isDone && !isFailed)
        .onAppear { if book.conversionState != .ready { start() } else { isDone = true } }
        .onDisappear { task?.cancel() }
    }

    private func start() {
        isFailed = false
        isDone = false
        fraction = 0
        task?.cancel()
        task = Task {
            // If this book uses a neural voice that's compiled in but not yet
            // downloaded, fetch it first (one-time, over the network). If the
            // download fails, conversion still proceeds with the system voice.
            if let voice = container.catalog.voice(withID: book.voiceID),
               voice.kind == .neural, NeuralTTS.isAvailable,
               !container.modelDownloader.isInstalled(voice.id) {
                statusText = "Downloading the \(voice.displayName) voice…"
                do {
                    try await container.modelDownloader.ensureInstalled(voice) { f in
                        fraction = f
                    }
                } catch {
                    // Non-fatal: fall back to the built-in voice for this book.
                }
                if Task.isCancelled { return }
                fraction = 0
            }

            for await progress in container.conversion.convert(book: book, modelContext: modelContext) {
                apply(progress)
            }
        }
    }

    private func apply(_ progress: ConversionProgress) {
        fraction = progress.fractionComplete
        switch progress.phase {
        case .extracting:
            statusText = "Reading the document…"
        case .synthesizing(let c, let s, let total):
            statusText = "Reading chapter \(c + 1) aloud… (\(s + 1)/\(max(total, 1)))"
        case .encoding(let c):
            statusText = "Saving chapter \(c + 1)…"
        case .finished:
            statusText = "All done! Ready for bedtime."
            isDone = true
        case .failed(let message):
            statusText = message
            isFailed = true
        case .cancelled:
            statusText = "Conversion cancelled."
        }
    }
}
