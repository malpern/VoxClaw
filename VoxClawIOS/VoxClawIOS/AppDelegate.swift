import UIKit
import VoxClawCore

/// Bridges UIKit app-delegate callbacks into the SwiftUI app. CloudKit silent
/// pushes (from the Mac relaying agent speech) are delivered here — including
/// when the app is backgrounded, suspended, or freshly launched by the push —
/// and handed to the coordinator to fetch and speak.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await SharedIOSApp.coordinator.handleCloudWake(
            appState: SharedIOSApp.appState,
            settings: SharedIOSApp.settings
        )
        return .newData
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // CloudKit routes its own pushes; we don't run a server, so nothing to send.
        SharedIOSApp.coordinator.cloudRelayStatus += " · APNs ✓"
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        SharedIOSApp.coordinator.cloudRelayStatus += " · APNs failed: \(error.localizedDescription)"
        print("Remote notification registration failed: \(error)")
    }
}
