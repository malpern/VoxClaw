import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsManager
    @State private var showingAPIKeyField = false

    var body: some View {
        Form {
            voiceSection
            playbackSection
        }
        .formStyle(.grouped)
        .frame(width: 440, height: settings.voiceEngine == .openai ? 460 : 420)
    }

    // MARK: - Voice

    @ViewBuilder
    private var voiceSection: some View {
        Section("Voice") {
            VoiceOptionCard(
                title: "Built-in Voice",
                subtitle: "Uses your Mac's text-to-speech. No setup required.",
                systemImage: "desktopcomputer",
                isSelected: settings.voiceEngine == .apple
            ) {
                settings.voiceEngine = .apple
            }

            VoiceOptionCard(
                title: "OpenAI Voice",
                subtitle: "Natural-sounding neural voices. Bring your own API key.",
                badge: "Higher Quality",
                systemImage: "waveform.circle",
                isSelected: settings.voiceEngine == .openai
            ) {
                settings.voiceEngine = .openai
            }
        }

        if settings.voiceEngine == .apple {
            appleVoiceSection
        } else {
            openAISetupSection
        }
    }

    @ViewBuilder
    private var appleVoiceSection: some View {
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

    @ViewBuilder
    private var openAISetupSection: some View {
        if settings.isOpenAIConfigured {
            // Configured state: show voice picker and key management
            Section("OpenAI Voice") {
                Picker("Voice", selection: $settings.openAIVoice) {
                    ForEach(openAIVoices, id: \.self) { voice in
                        Text(voice.capitalized).tag(voice)
                    }
                }

                HStack {
                    Label("API key saved", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Remove Key") {
                        settings.openAIAPIKey = ""
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
        } else {
            // Onboarding state: guide the user through setup
            Section("Connect OpenAI") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("To use OpenAI voices, paste your API key below.")
                        .font(.callout)

                    HStack(spacing: 4) {
                        Text("1.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link("Open platform.openai.com/api-keys",
                             destination: URL(string: "https://platform.openai.com/api-keys")!)
                            .font(.caption)
                    }
                    HStack(spacing: 4) {
                        Text("2.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Create a new key and copy it")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Text("3.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Paste it here:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        SecureField("sk-...", text: $settings.openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                        Button("Paste") {
                            if let clip = NSPasteboard.general.string(forType: .string) {
                                settings.openAIAPIKey = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }

                    Text("Your key is stored securely in your Mac's Keychain and never leaves your device except to authenticate with OpenAI.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }

        Section {
            Text("When using OpenAI, your reading text is sent to OpenAI for processing. [Privacy Policy](https://openai.com/privacy)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Playback

    private var playbackSection: some View {
        Section("Playback") {
            Toggle("Audio Only (no teleprompter overlay)", isOn: $settings.audioOnly)
        }
    }

    // MARK: - Helpers

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

// MARK: - Voice Option Card

private struct VoiceOptionCard: View {
    let title: String
    let subtitle: String
    var badge: String? = nil
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .fontWeight(isSelected ? .semibold : .regular)
                        if let badge {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(.capsule)
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
