import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The home screen: the shelf of imported books, an import button, and entry
/// points into conversion and playback.
struct LibraryView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.importedAt, order: .reverse) private var books: [Book]

    var onOpenPlayer: () -> Void

    @State private var showingImporter = false
    @State private var showingSettings = false
    @State private var conversionTarget: Book?

    var body: some View {
        Group {
            if books.isEmpty {
                EmptyLibraryView(onImport: { showingImporter = true })
            } else {
                List {
                    ForEach(books) { book in
                        BookRowView(book: book)
                            .contentShape(Rectangle())
                            .onTapGesture { open(book) }
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Bedtime Books")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingImporter = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add a book")
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: Self.importTypes,
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
        .sheet(item: $conversionTarget) { book in
            ConversionView(book: book)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
    }

    // MARK: Importing

    private static let importTypes: [UTType] = {
        var types: [UTType] = [.plainText, .pdf]
        for ext in ["md", "markdown", "txt"] {
            if let t = UTType(filenameExtension: ext) { types.append(t) }
        }
        // EPUB and DOCX by their declared identifiers (with extension fallback).
        if let epub = UTType("org.idpf.epub-container") ?? UTType(filenameExtension: "epub") { types.append(epub) }
        if let docx = UTType("org.openxmlformats.wordprocessingml.document") ?? UTType(filenameExtension: "docx") { types.append(docx) }
        return types
    }()

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let book = Book(
            title: url.deletingPathExtension().lastPathComponent,
            sourceFilename: url.lastPathComponent,
            voiceID: container.selectedVoiceID)
        do {
            _ = try container.storage.importSourceFile(from: url, bookID: book.id)
            modelContext.insert(book)
            try? modelContext.save()
            conversionTarget = book   // kick off conversion immediately
        } catch {
            modelContext.delete(book)
        }
    }

    // MARK: Opening

    private func open(_ book: Book) {
        switch book.conversionState {
        case .ready:
            guard let queue = PlaybackQueueBuilder.makeQueue(for: book, storage: container.storage) else { return }
            container.player.load(queue, autoplay: false)
            onOpenPlayer()
        case .failed, .pending:
            conversionTarget = book
        case .extracting, .converting:
            conversionTarget = book
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let book = books[index]
            container.storage.deleteBookStorage(bookID: book.id)
            modelContext.delete(book)
        }
        try? modelContext.save()
    }
}

private struct EmptyLibraryView: View {
    var onImport: () -> Void
    var body: some View {
        ContentUnavailableView {
            Label("No books yet", systemImage: "moon.stars")
        } description: {
            Text("Import an ebook or document and we'll turn it into a soothing audiobook for bedtime.")
        } actions: {
            Button("Add a Book", action: onImport)
                .buttonStyle(.borderedProminent)
        }
    }
}
