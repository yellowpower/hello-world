import SwiftUI

/// Lists the book's chapters and jumps playback to the selected one.
struct ChapterListView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let queue = player.queue {
                    ForEach(Array(queue.items.enumerated()), id: \.element.id) { offset, item in
                        Button {
                            player.jumpToChapter(offset)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: offset == player.currentIndex ? "speaker.wave.2.fill" : "circle")
                                    .foregroundStyle(offset == player.currentIndex ? .tint : .secondary)
                                Text(item.title).lineLimit(1)
                                Spacer()
                                Text(durationString(item.duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    private func durationString(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
