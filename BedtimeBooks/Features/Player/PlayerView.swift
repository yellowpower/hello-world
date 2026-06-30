import SwiftUI

/// The full-screen bedtime player: chapter title, scrubber, transport controls,
/// speed, sleep timer, and chapter list. Dark and calm by design.
struct PlayerView: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    @State private var showingSleepTimer = false
    @State private var showingChapters = false
    @State private var isScrubbing = false
    @State private var scrubValue: Double = 0

    var body: some View {
        @Bindable var player = player
        VStack(spacing: 28) {
            grabber
            artwork
            titleBlock
            scrubber
            transport
            bottomControls
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .background(
            LinearGradient(colors: [.black, .indigo.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea())
        .sheet(isPresented: $showingSleepTimer) {
            SleepTimerSheet().environment(player)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingChapters) {
            ChapterListView().environment(player)
        }
    }

    private var grabber: some View {
        Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.bottom, 4)
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(LinearGradient(colors: [.indigo, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(maxWidth: 280, maxHeight: 280)
            .overlay(Image(systemName: "moon.stars.fill").font(.system(size: 72)).foregroundStyle(.white.opacity(0.85)))
            .shadow(radius: 20)
            .padding(.vertical, 8)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text(player.currentItem?.title ?? "—")
                .font(.title3.bold()).multilineTextAlignment(.center).lineLimit(2)
            if let queue = player.queue {
                Text(queue.bookTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var scrubber: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { isScrubbing ? scrubValue : player.currentTime },
                    set: { scrubValue = $0 }),
                in: 0...max(player.currentDuration, 1),
                onEditingChanged: { editing in
                    isScrubbing = editing
                    if !editing { player.seek(to: scrubValue) }
                })
            HStack {
                Text(timeString(isScrubbing ? scrubValue : player.currentTime))
                Spacer()
                Text("-" + timeString(max(player.currentDuration - (isScrubbing ? scrubValue : player.currentTime), 0)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
    }

    private var transport: some View {
        HStack(spacing: 36) {
            Button { player.previous() } label: { Image(systemName: "backward.fill") }
            Button { player.skip(by: -15) } label: { Image(systemName: "gobackward.15") }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 68))
            }
            Button { player.skip(by: 15) } label: { Image(systemName: "goforward.15") }
            Button { player.next() } label: { Image(systemName: "forward.fill") }
        }
        .font(.title2)
        .buttonStyle(.plain)
        .tint(.white)
    }

    private var bottomControls: some View {
        HStack {
            Button { showingSleepTimer = true } label: {
                Label(sleepLabel, systemImage: "moon.zzz.fill")
                    .font(.callout)
            }
            Spacer()
            Menu {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button { player.playbackRate = rate } label: {
                        Label("\(rateString(rate))×", systemImage: player.playbackRate == rate ? "checkmark" : "")
                    }
                }
            } label: {
                Label("\(rateString(player.playbackRate))×", systemImage: "speedometer").font(.callout)
            }
            Spacer()
            Button { showingChapters = true } label: {
                Label("Chapters", systemImage: "list.bullet").font(.callout)
            }
        }
        .tint(.white.opacity(0.9))
        .padding(.top, 4)
    }

    private var sleepLabel: String {
        guard player.sleepTimer.isActive else { return "Sleep" }
        if let remaining = player.sleepTimer.remaining {
            return timeString(remaining)
        }
        return player.sleepTimer.option.label
    }

    private func rateString(_ r: Double) -> String {
        r == r.rounded() ? String(Int(r)) : String(format: "%.2g", r)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let total = Int(t.rounded())
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
