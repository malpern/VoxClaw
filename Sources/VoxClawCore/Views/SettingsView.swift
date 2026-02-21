import AVFoundation
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsManager

    @State private var copiedAgentHandoff = false
    @State private var showVoiceControls = true
    @State private var showBehaviorControls = true
    @State private var showNetworkControls = true
    @State private var showConnectionData = true
    @State private var showStatusData = false
    @State private var showAgentPasteBlock = false

    var body: some View {
        Form {
            agentSetupSection
            featureSwitchesSection
            readOnlyDataSection
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 720)
    }

    private var agentSetupSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text("🦞")
                        .font(.title2)
                    Text("Tell your agent how to use VoxClaw to get a voice.")
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(primaryAgentActionTitle) {
                    if !settings.networkListenerEnabled {
                        settings.networkListenerEnabled = true
                    }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(agentHandoffText, forType: .string)
                    copiedAgentHandoff = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedAgentHandoff = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(websiteRed)

                if copiedAgentHandoff {
                    Label("Copied. Paste this into OpenClaw.", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if !settings.networkListenerEnabled {
                    Label("This will enable listener and copy setup text.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                collapsibleBlock("Setup Text Preview", isExpanded: $showAgentPasteBlock) {
                    Text(agentHandoffText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var featureSwitchesSection: some View {
        Section("Feature Switches") {
            collapsibleBlock("Voice and API", isExpanded: $showVoiceControls) {
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
                }
            }

            collapsibleBlock("Playback and Startup", isExpanded: $showBehaviorControls) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Pause other audio while VoxClaw speaks", isOn: $settings.pauseOtherAudioDuringSpeech)
                    Toggle("Audio only (hide teleprompter overlay)", isOn: $settings.audioOnly)
                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                }
            }

            collapsibleBlock("Network Listener", isExpanded: $showNetworkControls) {
                Toggle("Enable Network Listener", isOn: $settings.networkListenerEnabled)

                if settings.networkListenerEnabled {
                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("4140", value: $settings.networkListenerPort, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
        }
    }

    private var readOnlyDataSection: some View {
        Section("Read-Only Data") {
            collapsibleBlock("Connection URLs", isExpanded: $showConnectionData) {
                LabeledContent("Status URL") {
                    Text("\(networkBaseURL)/status")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }

                LabeledContent("Speak URL") {
                    Text("\(networkBaseURL)/read")
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            collapsibleBlock("Current Status", isExpanded: $showStatusData) {
                LabeledContent("OpenAI Key") {
                    Text(settings.isOpenAIConfigured ? "Present in Keychain" : "Not configured")
                        .foregroundStyle(settings.isOpenAIConfigured ? .green : .secondary)
                }
                LabeledContent("Voice Engine") {
                    Text(settings.voiceEngine == .openai ? "OpenAI" : "Apple")
                }
                LabeledContent("Network Listener") {
                    Text(settings.networkListenerEnabled ? "Enabled" : "Disabled")
                }
                LabeledContent("Listener Port") {
                    Text(String(settings.networkListenerPort))
                }
                LabeledContent("LAN IP") {
                    Text(NetworkListener.localIPAddress() ?? "Unavailable")
                }
            }
        }
    }

    @ViewBuilder
    private func collapsibleBlock<Content: View>(
        _ title: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
                    .padding(.leading, 2)
            }
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

    private var primaryAgentActionTitle: String {
        settings.networkListenerEnabled ? "Copy Agent Setup" : "Enable Listener & Copy Setup"
    }

    private var websiteRed: Color {
        Color(red: 0.86, green: 0.16, blue: 0.14)
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
