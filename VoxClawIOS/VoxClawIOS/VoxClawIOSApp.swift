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
                // The "Now reading" Live Activity is driven by iOSCoordinator (not
                // here), so it also runs when the app is woken in the background by
                // a relay push — the view's observers don't fire when locked.
        }
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
