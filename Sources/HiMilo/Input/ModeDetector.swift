import Foundation
import os

enum AppMode: Sendable {
    case cli(text: String?)
    case menuBar
}

enum ModeDetector {
    static func detect() -> AppMode {
        let args = ProcessInfo.processInfo.arguments
        // args[0] is the executable path, skip it.
        // Filter out macOS-injected arguments (e.g. -NSDocumentRevisionsDebugMode, -psn_*).
        let userArgs = args.dropFirst().filter { !$0.hasPrefix("-NS") && !$0.hasPrefix("-psn") }

        Log.app.debug("ModeDetector: argCount=\(args.count, privacy: .public), userArgs=\(userArgs.count, privacy: .public), isApp=\(isRunningAsApp, privacy: .public), isatty=\(isatty(STDIN_FILENO), privacy: .public)")

        // If there are CLI arguments (beyond the executable), it's CLI mode
        if !userArgs.isEmpty {
            Log.app.debug("ModeDetector → cli (has user args)")
            return .cli(text: nil) // CLIParser will handle actual parsing
        }

        // When launched inside a .app bundle (Finder, open, launchd), stdin is
        // not a tty but that doesn't mean data is piped. Go straight to menu bar.
        if isRunningAsApp {
            Log.app.debug("ModeDetector → menuBar (running as .app)")
            return .menuBar
        }

        // Terminal launch with piped stdin → CLI mode
        if !isatty(STDIN_FILENO).boolValue {
            Log.app.debug("ModeDetector → cli (piped stdin)")
            return .cli(text: nil)
        }

        // No args, no piped input → menu bar mode
        Log.app.debug("ModeDetector → menuBar (no args, no pipe)")
        return .menuBar
    }

    private static var isRunningAsApp: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }
}

private extension Int32 {
    var boolValue: Bool { self != 0 }
}
