import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsManager

    @State private var copiedAgentHandoff = false
    @State private var showOpenAISetup = true
    @State private var showNetworkAdvanced = false
    @State private var showAgentPasteBlock = false

    var body: some View {
        Form {
            voiceSection
            playbackSection
            networkSection
            generalSection
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 700)
    }

    private var voiceSection: some View {
        Section("Voice") {
            Picker("Engine", selection: $settings.voiceEngine) {
                Text("Apple").tag(VoiceEngineType.apple)
                Text("OpenAI").tag(VoiceEngineType.openai)
            }
            .pickerStyle(.segmented)

            if settings.voiceEngine == .apple {
                Picker("Apple Voice", selection: appleVoiceBinding) {
                    Text("System Default").tag("" as String)
                    ForEach(availableAppleVoices, id: \.identifier) { voice in
                        Text("\(voice.name) (\(voice.language))")
                            .tag(voice.identifier)
                    }
                }
            } else {
                Picker("OpenAI Voice", selection: $settings.openAIVoice) {
                    ForEach(openAIVoices, id: \.self) { voice in
                        Text(voice.capitalized).tag(voice)
                    }
                }

                DisclosureGroup("OpenAI Setup", isExpanded: $showOpenAISetup) {
                    VStack(alignment: .leading, spacing: 10) {
                        if settings.isOpenAIConfigured {
                            Label("API key saved in Keychain", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Label("No API key configured", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
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

                        HStack(spacing: 12) {
                            Link("Get API key", destination: URL(string: "https://platform.openai.com/api-keys")!)
                            if settings.isOpenAIConfigured {
                                Button("Remove Key", role: .destructive) {
                                    settings.openAIAPIKey = ""
                                }
                            }
                        }

                        Text("Your key is stored in macOS Keychain.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                Text("Using OpenAI sends reading text to OpenAI for speech generation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playbackSection: some View {
        Section("Playback") {
            Toggle("Pause other audio while VoxClaw speaks", isOn: $settings.pauseOtherAudioDuringSpeech)
            Toggle("Audio only (hide teleprompter overlay)", isOn: $settings.audioOnly)
        }
    }

    @ViewBuilder
    private var networkSection: some View {
        Section("Network") {
            Toggle("Listen for network requests", isOn: $settings.networkListenerEnabled)

            if settings.networkListenerEnabled {
                LabeledContent("Speak URL") {
                    Text("\(networkBaseURL)/read")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                LabeledContent("Health URL") {
                    Text("\(networkBaseURL)/status")
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }

                HStack {
                    Button(copiedAgentHandoff ? "Copied" : "Copy Agent Setup") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(agentHandoffText, forType: .string)
                        copiedAgentHandoff = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            copiedAgentHandoff = false
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(showAgentPasteBlock ? "Hide Details" : "Show Details") {
                        showAgentPasteBlock.toggle()
                    }
                }

                if showAgentPasteBlock {
                    Text(agentHandoffText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                DisclosureGroup("Advanced Network", isExpanded: $showNetworkAdvanced) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("4140", value: $settings.networkListenerPort, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }

                        Text("Accepts POST /read and GET /status.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
        }
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

    private var networkBaseURL: String {
        let lanIP = NetworkListener.localIPAddress()
        return lanIP.map { "http://\($0):\(settings.networkListenerPort)" }
            ?? "http://<lan-ip>:\(settings.networkListenerPort)"
    }

    private var agentHandoffText: String {
        let healthURL = "\(networkBaseURL)/status"
        let speakURL = "\(networkBaseURL)/read"
        return """
        🦞 VoxClaw setup pointer:
        health_url: \(healthURL)
        speak_url: \(speakURL)

        Agent rules:
        1) GET health_url first.
        2) If status is ok, POST text to speak_url.
        3) Use these URLs exactly (no .local/discovery rewrite unless a human explicitly asks).

        Website: https://voxclaw.com/
        Skill doc: https://github.com/malpern/VoxClaw/blob/main/SKILL.md
        """
    }

    private let openAIVoices = ["alloy", "ash", "coral", "echo", "fable", "nova", "onyx", "sage", "shimmer"]
}
