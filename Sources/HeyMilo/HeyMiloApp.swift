import SwiftUI

@main
struct HeyMiloLauncher {
    static func main() {
        let mode = ModeDetector.detect()
        switch mode {
        case .cli:
            CLIParser.main()
        case .menuBar:
            HeyMiloApp.main()
        }
    }
}

struct HeyMiloApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("HeyMilo", systemImage: "waveform") {
            MenuBarView(appState: appState)
        }
    }
}
