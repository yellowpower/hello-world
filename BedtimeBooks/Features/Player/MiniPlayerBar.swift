import SwiftUI

/// A compact now-playing bar docked above the library. Hidden when nothing is
/// loaded. Tapping it opens the full player.
struct MiniPlayerBar: View {
    @Environment(AudioPlayerService.self) private var player
    var onTap: () -> Void

    var body: some View {
        if let item = player.currentItem, let queue = player.queue {
            HStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(queue.bookTitle).font(.subheadline.bold()).lineLimit(1)
                    Text(item.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
        }
    }
}
