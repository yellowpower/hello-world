import SwiftUI

/// Picker for the sleep timer. The active option drives a fade-out-and-pause
/// when it elapses (or at end of chapter).
struct SleepTimerSheet: View {
    @Environment(AudioPlayerService.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SleepTimer.Option.allCases) { option in
                        Button {
                            player.sleepTimer.set(option)
                            dismiss()
                        } label: {
                            HStack {
                                Text(option.label)
                                Spacer()
                                if player.sleepTimer.option == option {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } footer: {
                    Text("When the timer ends, playback gently fades out so your child can drift off.")
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
