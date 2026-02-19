import Foundation
import os

enum VoiceEngineType: String, CaseIterable, Sendable {
    case apple = "apple"
    case openai = "openai"
}

@Observable
@MainActor
final class SettingsManager {
    var voiceEngine: VoiceEngineType {
        get { VoiceEngineType(rawValue: UserDefaults.standard.string(forKey: "voiceEngine") ?? "apple") ?? .apple }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "voiceEngine") }
    }

    var openAIAPIKey: String {
        get { (try? SandboxedKeychainHelper.readAPIKey()) ?? "" }
        set {
            if newValue.isEmpty {
                try? SandboxedKeychainHelper.deleteAPIKey()
            } else {
                try? SandboxedKeychainHelper.saveAPIKey(newValue)
            }
        }
    }

    var openAIVoice: String {
        get { UserDefaults.standard.string(forKey: "openAIVoice") ?? "onyx" }
        set { UserDefaults.standard.set(newValue, forKey: "openAIVoice") }
    }

    var appleVoiceIdentifier: String? {
        get { UserDefaults.standard.string(forKey: "appleVoiceIdentifier") }
        set { UserDefaults.standard.set(newValue, forKey: "appleVoiceIdentifier") }
    }

    var audioOnly: Bool {
        get { UserDefaults.standard.bool(forKey: "audioOnly") }
        set { UserDefaults.standard.set(newValue, forKey: "audioOnly") }
    }

    /// Whether OpenAI is configured and usable.
    var isOpenAIConfigured: Bool {
        !openAIAPIKey.isEmpty
    }

    /// Create the appropriate SpeechEngine based on current settings.
    func createEngine() -> any SpeechEngine {
        switch voiceEngine {
        case .apple:
            return AppleSpeechEngine(voiceIdentifier: appleVoiceIdentifier)
        case .openai:
            guard isOpenAIConfigured else {
                Log.settings.info("OpenAI selected but no API key — falling back to Apple")
                return AppleSpeechEngine(voiceIdentifier: appleVoiceIdentifier)
            }
            return OpenAISpeechEngine(apiKey: openAIAPIKey, voice: openAIVoice)
        }
    }
}
