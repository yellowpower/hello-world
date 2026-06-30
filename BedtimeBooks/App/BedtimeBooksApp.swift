import SwiftUI
import SwiftData

@main
struct BedtimeBooksApp: App {
    @State private var container = AppContainer()

    /// SwiftData stack for the library.
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: Book.self, Chapter.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .preferredColorScheme(.dark) // calm, dim UI for bedtime
        }
        .modelContainer(modelContainer)
    }
}
