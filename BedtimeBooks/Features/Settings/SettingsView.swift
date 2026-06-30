import SwiftUI

/// App settings: voice selection plus credits/licenses. Kept simple and
/// kid-safe (no external links without a parental gate — added in M4).
struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var container = container
        List {
            Section("Voice") {
                NavigationLink {
                    VoicePickerView()
                } label: {
                    HStack {
                        Text("Reading voice")
                        Spacer()
                        Text(currentVoiceName).foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Choose the voice used to read new books. Natural neural voices download once, then work offline.")
            }

            Section("About") {
                NavigationLink("Credits & Licenses") { AboutLicensesView() }
                HStack {
                    Text("Version")
                    Spacer()
                    Text(appVersion).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
    }

    private var currentVoiceName: String {
        container.catalog.voice(withID: container.selectedVoiceID)?.displayName ?? "Built-in"
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return v
    }
}
