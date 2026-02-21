@testable import VoxClawCore
import Testing

struct TTSServiceTests {
    @Test func httpErrorPreservesStatusCodeForAuthFailures() {
        let error = TTSService.httpError(status: 401, body: #"{"error":"invalid key"}"#)
        #expect(error.statusCode == 401)
        #expect(error.message.contains("Invalid OpenAI API key"))
    }

    @Test func httpErrorUsesBodyForUnknownStatuses() {
        let error = TTSService.httpError(status: 418, body: "teapot body")
        #expect(error.statusCode == 418)
        #expect(error.message.contains("HTTP 418"))
        #expect(error.message.contains("teapot body"))
    }
}
