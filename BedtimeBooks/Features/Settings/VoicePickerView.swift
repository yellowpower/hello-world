import SwiftUI
import BedtimeBooksCore

/// Lists available voices from the bundled catalog. Selecting one updates which
/// voice new conversions use. Neural voices show their size and license.
struct VoicePickerView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var container = container
        List(container.catalog.voices) { voice in
            Button {
                container.selectedVoiceID = voice.id
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: voice.kind == .neural ? "waveform.badge.mic" : "speaker.wave.2")
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(voice.displayName).font(.headline)
                        Text(voice.blurb).font(.caption).foregroundStyle(.secondary)
                        if voice.kind == .neural, let size = voice.approxSizeMB {
                            Text("Neural • ~\(size) MB download • \(voice.license ?? "")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if container.selectedVoiceID == voice.id {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                    }
                }
            }
            .tint(.primary)
        }
        .navigationTitle("Reading Voice")
        .navigationBarTitleDisplayMode(.inline)
    }
}
