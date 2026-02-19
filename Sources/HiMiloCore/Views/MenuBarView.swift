import os
import ServiceManagement
import SwiftUI

struct MenuBarView: View {
    let appState: AppState
    let settings: SettingsManager
    var onTogglePause: () -> Void = {}
    var onStop: () -> Void = {}
    var onReadText: (String) async -> Void = { _ in }

    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Group {
            if appState.isActive {
                Button(appState.isPaused ? "Resume" : "Pause") {
                    onTogglePause()
                }
                .keyboardShortcut(" ", modifiers: [])

                Button("Stop") {
                    onStop()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Divider()
            }

            Button("Paste & Read") {
                Task { await pasteAndRead() }
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button("Read from File...") {
                Task { await readFromFile() }
            }

            Divider()

            Toggle("Audio Only Mode", isOn: Binding(
                get: { settings.audioOnly },
                set: { settings.audioOnly = $0 }
            ))

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        Log.app.error("Launch at login error: \(error)")
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

            Divider()

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)

            Menu("HiMilo Companion CLI") {
                Text("For terminal workflows, piping,")
                Text("and network listener mode.")
                Divider()
                Link("Learn More...", destination: URL(string: "https://github.com/malpern/HiMilo")!)
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    @MainActor
    private func pasteAndRead() async {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return
        }
        await onReadText(text)
    }

    @MainActor
    private func readFromFile() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            await onReadText(text)
        } catch {
            Log.app.error("Error reading file: \(error)")
        }
    }
}
