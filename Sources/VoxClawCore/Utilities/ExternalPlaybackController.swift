import AppKit
import Foundation

@MainActor
protocol ExternalPlaybackControlling {
    func pauseIfPlaying() -> Bool
    func resumePaused()
}

@MainActor
final class ExternalPlaybackController: ExternalPlaybackControlling {
    private var pausedApps: Set<String> = []

    func pauseIfPlaying() -> Bool {
        pausedApps.removeAll()

        if isMusicPlaying() {
            runAppleScript("""
            tell application "Music"
                pause
            end tell
            """)
            pausedApps.insert("Music")
        }

        if isSpotifyPlaying() {
            runAppleScript("""
            tell application "Spotify"
                pause
            end tell
            """)
            pausedApps.insert("Spotify")
        }

        return !pausedApps.isEmpty
    }

    func resumePaused() {
        defer { pausedApps.removeAll() }

        if pausedApps.contains("Music") {
            runAppleScript("""
            tell application "Music"
                play
            end tell
            """)
        }

        if pausedApps.contains("Spotify") {
            runAppleScript("""
            tell application "Spotify"
                play
            end tell
            """)
        }
    }

    private func isMusicPlaying() -> Bool {
        runAppleScript("""
        tell application "System Events"
            set musicRunning to (name of processes) contains "Music"
        end tell
        if musicRunning then
            tell application "Music"
                if player state is playing then
                    return "yes"
                end if
            end tell
        end if
        return "no"
        """) == "yes"
    }

    private func isSpotifyPlaying() -> Bool {
        runAppleScript("""
        tell application "System Events"
            set spotifyRunning to (name of processes) contains "Spotify"
        end tell
        if spotifyRunning then
            tell application "Spotify"
                if player state is playing then
                    return "yes"
                end if
            end tell
        end if
        return "no"
        """) == "yes"
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var errorDict: NSDictionary?
        let script = NSAppleScript(source: source)
        let output = script?.executeAndReturnError(&errorDict)
        if let errorDict {
            Log.app.error("AppleScript playback control error: \(String(describing: errorDict), privacy: .public)")
            return nil
        }
        return output?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
