import os
import SwiftUI

public struct HiMiloLauncher {
    @MainActor public static func main() {
        let args = ProcessInfo.processInfo.arguments
        Log.app.info("launch args: \(args, privacy: .public)")
        Log.app.info("bundlePath: \(Bundle.main.bundlePath, privacy: .public)")
        Log.app.debug("isatty: \(isatty(STDIN_FILENO), privacy: .public)")

        let mode = ModeDetector.detect()
        Log.app.info("mode: \(String(describing: mode), privacy: .public)")

        switch mode {
        case .cli:
            Log.app.info("entering CLI mode")
            CLIParser.main()
        case .menuBar:
            Log.app.info("entering menuBar mode")
            HiMiloApp.main()
        }
    }
}

struct HiMiloApp: App {
    @State private var appState = AppState()
    @State private var coordinator = AppCoordinator()
    @State private var settings = SettingsManager()

    init() {
        Log.app.info("App init, creating MenuBarExtra")
    }

    var body: some Scene {
        MenuBarExtra("HiMilo", systemImage: "waveform") {
            MenuBarView(
                appState: appState,
                settings: settings,
                onTogglePause: { coordinator.togglePause() },
                onStop: { coordinator.stop() },
                onReadText: { text in await coordinator.readText(text, appState: appState, settings: settings) }
            )
            .task {
                await coordinator.handleCLILaunch(appState: appState, settings: settings)
            }
        }

        Window("Settings", id: "settings") {
            SettingsView(settings: settings)
        }
        .defaultSize(width: 400, height: 320)
    }
}

@Observable
@MainActor
final class AppCoordinator {
    private var networkListener: NetworkListener?
    private var activeSession: ReadingSession?

    // Network listener — used by CLI --listen mode only
    func startListening(appState: AppState, port: UInt16? = nil) {
        let port = port ?? CLIContext.shared?.port ?? 4140
        let listener = NetworkListener(port: port, appState: appState)
        do {
            try listener.start { [weak self] text in
                await self?.readTextCLI(text, appState: appState)
            }
            self.networkListener = listener
        } catch {
            Log.app.error("Failed to start listener: \(error)")
        }
    }

    func stopListening() {
        networkListener?.stop()
        networkListener = nil
    }

    /// Menu bar app path — uses settings to pick the right engine.
    func readText(_ text: String, appState: AppState, settings: SettingsManager) async {
        activeSession?.stop()

        appState.audioOnly = settings.audioOnly
        let engine = settings.createEngine()
        let session = ReadingSession(appState: appState, engine: engine)
        activeSession = session
        await session.start(text: text)
    }

    /// CLI path — tries KeychainHelper (env var / system keychain) for OpenAI, falls back to Apple.
    func readTextCLI(_ text: String, appState: AppState, voice: String = "onyx", audioOnly: Bool = false) async {
        activeSession?.stop()

        let engine: any SpeechEngine
        if let apiKey = try? KeychainHelper.readAPIKey() {
            engine = OpenAISpeechEngine(apiKey: apiKey, voice: voice)
        } else {
            engine = AppleSpeechEngine()
        }

        appState.audioOnly = audioOnly
        let session = ReadingSession(appState: appState, engine: engine)
        activeSession = session
        await session.start(text: text)
    }

    func togglePause() {
        activeSession?.togglePause()
    }

    func stop() {
        activeSession?.stop()
        activeSession = nil
    }

    func handleCLILaunch(appState: AppState, settings: SettingsManager) async {
        guard let context = CLIContext.shared else { return }

        // Small delay to let the app finish initializing
        try? await Task.sleep(for: .milliseconds(100))

        if context.listen {
            startListening(appState: appState, port: context.port)
        } else if let text = context.text {
            await readTextCLI(text, appState: appState, voice: context.voice, audioOnly: context.audioOnly)
        }
    }
}
