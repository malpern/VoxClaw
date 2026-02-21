@testable import VoxClawCore
import Foundation
import Testing

@MainActor
private final class OpenAIEngineDelegateMock: SpeechEngineDelegate {
    var didEncounterError = false

    func speechEngine(_ engine: any SpeechEngine, didUpdateWordIndex index: Int) {}
    func speechEngineDidFinish(_ engine: any SpeechEngine) {}
    func speechEngine(_ engine: any SpeechEngine, didChangeState state: SpeechEngineState) {}
    func speechEngine(_ engine: any SpeechEngine, didEncounterError error: Error) {
        didEncounterError = true
    }
}

private actor NotificationFlag {
    private(set) var posted = false
    private(set) var message: String?
    func markPosted() { posted = true }
    func setMessage(_ value: String?) { message = value }
}

@MainActor
@Suite(.serialized)
struct OpenAISpeechEngineTests {
    @Test func postsAuthFailureNotificationOn401Error() async throws {
        let engine = OpenAISpeechEngine(apiKey: "sk-invalid")
        let delegate = OpenAIEngineDelegateMock()
        engine.delegate = delegate

        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .voxClawOpenAIAuthFailed,
            object: nil,
            queue: .main
        ) { note in
            let message = note.userInfo?[VoxClawNotificationUserInfo.openAIAuthErrorMessage] as? String
            Task {
                await flag.markPosted()
                await flag.setMessage(message)
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        engine.handleEngineError(TTSService.TTSError(message: "Unauthorized", statusCode: 401))
        try await Task.sleep(for: .milliseconds(20))

        #expect(await flag.posted)
        #expect(await flag.message == "Unauthorized")
        #expect(delegate.didEncounterError)
    }

    @Test func doesNotPostAuthFailureNotificationForNon401() async throws {
        let engine = OpenAISpeechEngine(apiKey: "sk-invalid")
        let delegate = OpenAIEngineDelegateMock()
        engine.delegate = delegate

        let flag = NotificationFlag()
        let token = NotificationCenter.default.addObserver(
            forName: .voxClawOpenAIAuthFailed,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await flag.markPosted()
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        engine.handleEngineError(TTSService.TTSError(message: "Rate limited", statusCode: 429))
        try await Task.sleep(for: .milliseconds(20))

        #expect(!(await flag.posted))
        #expect(delegate.didEncounterError)
    }
}
