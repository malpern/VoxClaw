import ArgumentParser
import Foundation

struct CLIParser: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "milo",
        abstract: "Read text aloud with a teleprompter overlay"
    )

    @Flag(name: [.short, .customLong("audio-only")], help: "Play audio without showing the overlay")
    var audioOnly = false

    @Flag(name: [.short, .long], help: "Read text from clipboard")
    var clipboard = false

    @Option(name: [.short, .long], help: "Read text from a file")
    var file: String? = nil

    @Option(name: .long, help: "TTS voice (default: onyx)")
    var voice: String = "onyx"

    @Argument(help: "Text to read aloud")
    var text: [String] = []

    func run() throws {
        let resolvedText = try InputResolver.resolve(
            positional: text,
            clipboardFlag: clipboard,
            filePath: file
        )

        guard !resolvedText.isEmpty else {
            throw ValidationError("No text provided. Use arguments, --clipboard, --file, or pipe via stdin.")
        }

        // Launch the app with CLI context
        let cliContext = CLIContext(text: resolvedText, audioOnly: audioOnly, voice: voice)
        CLIContext.shared = cliContext
        HeyMiloApp.main()
    }
}

final class CLIContext: Sendable {
    nonisolated(unsafe) static var shared: CLIContext?

    let text: String
    let audioOnly: Bool
    let voice: String

    init(text: String, audioOnly: Bool, voice: String) {
        self.text = text
        self.audioOnly = audioOnly
        self.voice = voice
    }
}
