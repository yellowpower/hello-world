import SwiftUI
import BedtimeBooksCore

/// Lists available voices from the bundled catalog. Selecting one updates which
/// voice new conversions use. Neural voices show their size/license and a
/// download control so the model can be fetched ahead of time.
struct VoicePickerView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        @Bindable var container = container
        List(container.catalog.voices) { voice in
            HStack(alignment: .top, spacing: 12) {
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
                                Text("Neural • ~\(size) MB • \(voice.license ?? "")")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            neuralStatus(for: voice)
                        }
                        Spacer()
                        if container.selectedVoiceID == voice.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
        }
        .navigationTitle("Reading Voice")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func neuralStatus(for voice: VoiceDescriptor) -> some View {
        if voice.kind == .neural {
            if !NeuralTTS.isAvailable {
                Label("Neural engine not in this build — will use the built-in voice",
                      systemImage: "info.circle")
                    .font(.caption2).foregroundStyle(.orange)
            } else {
                switch container.modelDownloader.status(for: voice.id) {
                case .installed:
                    Label("Downloaded", systemImage: "checkmark.circle")
                        .font(.caption2).foregroundStyle(.green)
                case .downloading(let f):
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Downloading… \(Int(f * 100))%").font(.caption2).foregroundStyle(.secondary)
                        ProgressView(value: f).frame(maxWidth: 180)
                    }
                case .installing:
                    Label("Installing…", systemImage: "shippingbox").font(.caption2).foregroundStyle(.secondary)
                case .failed(let message):
                    VStack(alignment: .leading, spacing: 2) {
                        Label(message, systemImage: "exclamationmark.triangle").font(.caption2).foregroundStyle(.red)
                        downloadButton(voice, title: "Try again")
                    }
                case .notInstalled:
                    downloadButton(voice, title: "Download voice")
                }
            }
        }
    }

    private func downloadButton(_ voice: VoiceDescriptor, title: String) -> some View {
        Button {
            Task { try? await container.modelDownloader.ensureInstalled(voice) }
        } label: {
            Label(title, systemImage: "arrow.down.circle").font(.caption2)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
