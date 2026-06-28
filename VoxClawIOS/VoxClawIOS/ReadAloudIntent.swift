import VoxClawCore

/// Globally-reachable iOS app state shared between the SwiftUI app and any code
/// that runs outside the view hierarchy. Mirrors macOS `SharedApp`.
@MainActor
enum SharedIOSApp {
    static let appState = AppState()
    static let settings = SettingsManager()
    static let coordinator = iOSCoordinator()
}
