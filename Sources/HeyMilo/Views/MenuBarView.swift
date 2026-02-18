import SwiftUI

struct MenuBarView: View {
    let appState: AppState

    var body: some View {
        Group {
            if appState.isActive {
                Button(appState.isPaused ? "Resume" : "Pause") {
                    Task { await togglePause() }
                }
                .keyboardShortcut(" ", modifiers: [])

                Button("Stop") {
                    Task { await stop() }
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

            Toggle("Audio Only Mode", isOn: Binding(
                get: { appState.audioOnly },
                set: { appState.audioOnly = $0 }
            ))

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func togglePause() async {
        appState.isPaused.toggle()
        appState.sessionState = appState.isPaused ? .paused : .playing
    }

    private func stop() async {
        appState.reset()
    }

    @MainActor
    private func pasteAndRead() async {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            return
        }
        appState.inputText = text
        let session = ReadingSession(appState: appState)
        await session.start(text: text)
    }

    @MainActor
    private func readFromFile() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            appState.inputText = text
            let session = ReadingSession(appState: appState)
            await session.start(text: text)
        } catch {
            print("Error reading file: \(error)")
        }
    }
}
