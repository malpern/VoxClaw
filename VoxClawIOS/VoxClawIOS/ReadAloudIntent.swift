import AppIntents
import VoxClawCore

/// Globally-reachable iOS app state shared between the SwiftUI app and any code
/// that runs outside the view hierarchy. Mirrors macOS `SharedApp`.
@MainActor
enum SharedIOSApp {
    static let appState = AppState()
    static let settings = SettingsManager()
    static let coordinator = iOSCoordinator()
}

/// "Read Text Aloud" — exposes VoxClaw to Siri, Spotlight, and Shortcuts on iOS.
/// (macOS has its own `ReadTextIntent` in VoxClawCore; this is the iOS counterpart.)
struct ReadTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Read Text Aloud"
    static let description = IntentDescription(
        "Reads the provided text aloud using VoxClaw's text-to-speech.",
        categoryName: "Reading"
    )
    // Bring the app forward so the audio session is active and the teleprompter shows.
    static let openAppWhenRun = true

    @Parameter(title: "Text to Read")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("Read \(\.$text) aloud")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        await SharedIOSApp.coordinator.readText(
            text,
            appState: SharedIOSApp.appState,
            settings: SharedIOSApp.settings
        )
        return .result()
    }
}

/// Registers the discoverable shortcut/phrases for Siri and Spotlight.
struct VoxClawShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ReadTextIntent(),
            phrases: [
                "Read with \(.applicationName)",
                "Read text using \(.applicationName)",
            ],
            shortTitle: "Read Text",
            systemImageName: "waveform"
        )
    }
}
