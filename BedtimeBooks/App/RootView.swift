import SwiftUI
import SwiftData

/// App shell: the library is home; the mini-player docks at the bottom and
/// expands into the full player.
struct RootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    @State private var showingPlayer = false
    @State private var persistence: LibraryPersistence?

    var body: some View {
        NavigationStack {
            LibraryView(onOpenPlayer: { showingPlayer = true })
                .safeAreaInset(edge: .bottom) {
                    MiniPlayerBar(onTap: { showingPlayer = true })
                        .environment(container.player)
                }
        }
        .sheet(isPresented: $showingPlayer) {
            PlayerView()
                .environment(container.player)
        }
        .onAppear {
            // Wire resume-position persistence into the player once we have a
            // model context.
            if persistence == nil {
                let p = LibraryPersistence(modelContext: modelContext)
                container.player.persistence = p
                persistence = p
            }
        }
    }
}

/// Persists throttled resume positions from the player back into SwiftData.
@MainActor
final class LibraryPersistence: PlaybackPersistence {
    private let modelContext: ModelContext
    init(modelContext: ModelContext) { self.modelContext = modelContext }

    func persistPlayback(bookID: UUID, chapterIndex: Int, position: TimeInterval) {
        let descriptor = FetchDescriptor<Book>(predicate: #Predicate { $0.id == bookID })
        guard let book = try? modelContext.fetch(descriptor).first else { return }
        book.lastPlayedChapterIndex = chapterIndex
        if let chapter = book.chapters.first(where: { $0.index == chapterIndex }) {
            chapter.positionInChapter = position
        }
        try? modelContext.save()
    }
}
