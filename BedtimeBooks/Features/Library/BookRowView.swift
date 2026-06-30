import SwiftUI

/// A single shelf row: cover placeholder, title/author, and a status badge
/// reflecting the book's conversion state.
struct BookRowView: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .top, endPoint: .bottom))
                .frame(width: 44, height: 60)
                .overlay(Image(systemName: "book.closed").foregroundStyle(.white.opacity(0.9)))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(.headline).lineLimit(2)
                if let author = book.author, !author.isEmpty {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
                statusBadge
            }
            Spacer()
            if book.isReady {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var statusBadge: some View {
        switch book.conversionState {
        case .ready:
            Label(durationText, systemImage: "headphones")
                .font(.caption).foregroundStyle(.secondary)
        case .pending:
            Label("Tap to convert", systemImage: "wand.and.stars")
                .font(.caption).foregroundStyle(.secondary)
        case .extracting, .converting:
            Label("Converting…", systemImage: "waveform")
                .font(.caption).foregroundStyle(.orange)
        case .failed:
            Label("Couldn't convert", systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red)
        }
    }

    private var durationText: String {
        let total = Int(book.totalDuration)
        guard total > 0 else { return "Ready" }
        let m = total / 60
        return m < 60 ? "\(m) min" : "\(m / 60)h \(m % 60)m"
    }
}
