import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsManager

    var body: some View {
        Form {
            Section("Voice Engine") {
                Picker("Engine", selection: $settings.voiceEngine) {
                    Text("Apple (Built-in)").tag(VoiceEngineType.apple)
                    Text("OpenAI").tag(VoiceEngineType.openai)
                }
                .pickerStyle(.radioGroup)
            }

            if settings.voiceEngine == .apple {
                Section("Apple Voice") {
                    Picker("Voice", selection: appleVoiceBinding) {
                        Text("System Default").tag("" as String)
                        ForEach(availableAppleVoices, id: \.identifier) { voice in
                            Text("\(voice.name) (\(voice.language))")
                                .tag(voice.identifier)
                        }
                    }
                }
            }

            if settings.voiceEngine == .openai {
                Section("OpenAI") {
                    SecureField("API Key", text: $settings.openAIAPIKey)
                        .textFieldStyle(.roundedBorder)

                    if !settings.isOpenAIConfigured {
                        Text("Enter your OpenAI API key to use premium voices.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Voice", selection: $settings.openAIVoice) {
                        ForEach(openAIVoices, id: \.self) { voice in
                            Text(voice.capitalized).tag(voice)
                        }
                    }
                }
            }

            Section("Playback") {
                Toggle("Audio Only (no overlay)", isOn: $settings.audioOnly)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 320)
    }

    private var appleVoiceBinding: Binding<String> {
        Binding(
            get: { settings.appleVoiceIdentifier ?? "" },
            set: { settings.appleVoiceIdentifier = $0.isEmpty ? nil : $0 }
        )
    }

    private var availableAppleVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.name < $1.name }
    }

    private let openAIVoices = ["alloy", "ash", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer"]
}
