import Foundation
import os

/// Plays a short phrase to preview an OpenAI voice selection.
/// Lightweight alternative to ReadingSession — no overlay, no app state changes.
@MainActor
public final class VoicePreviewPlayer {
    private var engine: (any SpeechEngine)?

    public init() {}

    /// Speaks a short preview phrase using the given OpenAI voice.
    /// Cancels any in-progress preview before starting.
    public func play(voice: String, apiKey: String, instructions: String?) {
        stop()

        let preview = Self.preview(for: voice)
        let words = preview.phrase.split(separator: " ").map(String.init)
        // Voice-specific personality instructions take priority for previews,
        // but layer on the user's custom reading style if set.
        let combinedInstructions: String
        if let userStyle = instructions {
            combinedInstructions = "\(preview.instructions) \(userStyle)"
        } else {
            combinedInstructions = preview.instructions
        }

        let engine = OpenAISpeechEngine(
            apiKey: apiKey,
            voice: voice,
            instructions: combinedInstructions
        )
        self.engine = engine

        Task {
            await engine.start(text: preview.phrase, words: words)
        }
    }

    public func stop() {
        engine?.stop()
        engine = nil
    }

    private struct Preview {
        let phrase: String
        let instructions: String
    }

    private static func preview(for voice: String) -> Preview {
        switch voice {
        case "alloy":
            return Preview(
                phrase: "Hey! I'm versatile and ready for anything you throw my way.",
                instructions: "Speak with friendly confidence and an upbeat energy."
            )
        case "ash":
            return Preview(
                phrase: "Let me walk you through this. I'll keep things clear and steady.",
                instructions: "Speak in a calm, composed, and authoritative tone."
            )
        case "coral":
            return Preview(
                phrase: "Oh, I love reading out loud! Let's make this fun.",
                instructions: "Speak with warmth and genuine enthusiasm, like chatting with a close friend."
            )
        case "echo":
            return Preview(
                phrase: "I bring a certain gravitas to the words. Listen closely.",
                instructions: "Speak with a deep, resonant, and slightly dramatic tone."
            )
        case "fable":
            return Preview(
                phrase: "Once upon a time, a voice began to tell a story, and it sounded just like this.",
                instructions: "Speak like a storyteller, with gentle wonder and expressive pacing."
            )
        case "nova":
            return Preview(
                phrase: "Hi there! I'm bright, clear, and ready to keep you company.",
                instructions: "Speak with a bright, cheerful, and energetic tone."
            )
        case "onyx":
            return Preview(
                phrase: "Sit back and relax. I've got a smooth delivery for the long haul.",
                instructions: "Speak with a rich, smooth, and relaxed baritone."
            )
        case "sage":
            return Preview(
                phrase: "Knowledge is best shared calmly. Let me read this to you with care.",
                instructions: "Speak with thoughtful, measured wisdom and gentle clarity."
            )
        case "shimmer":
            return Preview(
                phrase: "Every word deserves a little sparkle, don't you think?",
                instructions: "Speak with a light, playful, and slightly whimsical tone."
            )
        default:
            return Preview(
                phrase: "Hi, I'm \(voice). Here's what I sound like.",
                instructions: "Speak naturally and clearly."
            )
        }
    }
}
