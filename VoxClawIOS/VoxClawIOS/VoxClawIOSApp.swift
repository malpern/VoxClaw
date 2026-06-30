import AVFoundation
import SwiftUI
import UIKit
import VoxClawCore

@main
struct VoxClawIOSApp: App {
    // Shared singletons so App Intents (Siri/Spotlight/Shortcuts) drive the same
    // state as the UI.
    @State private var appState = SharedIOSApp.appState
    @State private var settings = SharedIOSApp.settings
    @State private var coordinator = SharedIOSApp.coordinator

    // Bridges remote-notification callbacks (CloudKit relay wake) into the app.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @Environment(\.scenePhase) private var scenePhase
    @State private var lastHandledClipboardRequest: TimeInterval = 0

    // App Group shared with the widget/control extension (which can't play audio).
    private static let appGroup = "group.com.malpern.voxclaw"
    private static let pendingReadClipboardKey = "voxclaw.pendingReadClipboard"

    var body: some Scene {
        WindowGroup {
            ContentView(appState: appState, settings: settings, coordinator: coordinator)
                .task {
                    configureAudioSession()
                    #if targetEnvironment(simulator)
                    if settings.networkListenerPort == 4140 {
                        settings.networkListenerPort = 4141
                    }
                    #endif
                    coordinator.startListening(appState: appState, settings: settings)
                    coordinator.observeAudioInterruptions(appState: appState)
                    if settings.cloudRelayEnabled {
                        UIApplication.shared.registerForRemoteNotifications()
                        await coordinator.ensureCloudRelay(settings: settings)
                    }
                }
                .onChange(of: settings.cloudRelayEnabled) { _, enabled in
                    guard enabled else { return }
                    UIApplication.shared.registerForRemoteNotifications()
                    Task { await coordinator.ensureCloudRelay(settings: settings) }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { handlePendingClipboardRead() }
                }
                // The "Now reading" Live Activity is driven by iOSCoordinator (not
                // here), so it also runs when the app is woken in the background by
                // a relay push — the view's observers don't fire when locked.
        }
    }

    /// When the Control Center control / widget asks to read the clipboard, it
    /// opens the app and sets a timestamp in the App Group; we read it here.
    @MainActor
    private func handlePendingClipboardRead() {
        guard let defaults = UserDefaults(suiteName: Self.appGroup) else { return }
        let ts = defaults.double(forKey: Self.pendingReadClipboardKey)
        guard ts > lastHandledClipboardRequest else { return }
        lastHandledClipboardRequest = ts
        guard let text = UIPasteboard.general.string, !text.isEmpty else { return }
        Task { await coordinator.readText(text, appState: appState, settings: settings) }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("AVAudioSession configuration failed: \(error)")
        }
    }
}
