import SwiftUI
import BedtimeBooksCore

/// Open-source attributions. The neural voice models and libraries we rely on
/// require attribution; this screen satisfies that and the App Store review
/// expectation for bundled OSS.
struct AboutLicensesView: View {
    @Environment(AppContainer.self) private var container

    private struct Credit: Identifiable {
        let id = UUID()
        let name: String
        let license: String
        let detail: String
    }

    private let libraries: [Credit] = [
        .init(name: "sherpa-onnx (k2-fsa)", license: "Apache-2.0", detail: "On-device neural TTS runtime."),
        .init(name: "ONNX Runtime", license: "MIT", detail: "Neural model inference."),
        .init(name: "espeak-ng", license: "GPL-3.0", detail: "Text phonemization (bundled with sherpa-onnx)."),
        .init(name: "ZIPFoundation", license: "MIT", detail: "EPUB/DOCX container reading."),
    ]

    var body: some View {
        List {
            Section("Voices") {
                ForEach(neuralVoiceCredits) { credit in
                    creditRow(credit)
                }
                if neuralVoiceCredits.isEmpty {
                    Text("Built-in Apple voices are provided by iOS.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Open-Source Libraries") {
                ForEach(libraries) { creditRow($0) }
            }
            Section {
                Text("Made with care for bedtime. All reading happens on your device — nothing is uploaded.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Credits & Licenses")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var neuralVoiceCredits: [Credit] {
        container.catalog.voices
            .filter { $0.kind == .neural }
            .map { Credit(name: $0.attribution ?? $0.displayName, license: $0.license ?? "—", detail: $0.blurb) }
    }

    private func creditRow(_ credit: Credit) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(credit.name).font(.headline)
            Text(credit.detail).font(.caption).foregroundStyle(.secondary)
            Text("License: \(credit.license)").font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
