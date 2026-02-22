import Foundation
import os

@MainActor
public final class OpenAISpeechEngine: SpeechEngine {
    public weak var delegate: SpeechEngineDelegate?
    public private(set) var state: SpeechEngineState = .idle

    private let apiKey: String
    private let voice: String
    private let speed: Float
    private let instructions: String?
    private var originalSpeed: Float = 1.0
    private var audioPlayer: AudioPlayer?
    private var cadenceTimings: [WordTiming] = []
    private var finalTimings: [WordTiming]?
    private var aligner: SpeechAligner?
    private var words: [String] = []
    private var displayLink: Timer?

    public init(apiKey: String, voice: String = "onyx", speed: Float = 1.0, instructions: String? = nil) {
        self.apiKey = apiKey
        self.voice = voice
        self.speed = speed
        self.instructions = instructions
    }

    public func start(text: String, words: [String]) async {
        self.words = words
        self.originalSpeed = speed
        self.finalTimings = nil
        state = .loading
        delegate?.speechEngine(self, didChangeState: .loading)

        // Cadence timings for immediate highlighting before aligner catches up.
        cadenceTimings = WordTimingEstimator.estimateCadence(words: words, rate: speed)

        do {
            let player = try AudioPlayer()
            self.audioPlayer = player
            let ttsService = TTSService(apiKey: apiKey, voice: voice, speed: speed, instructions: instructions)
            try player.prepare()

            let prebufferCount = 5
            let aligner = SpeechAligner(words: words)
            self.aligner = aligner
            let stream = await ttsService.streamPCM(text: text)
            var chunksBuffered = 0

            for try await chunk in stream {
                player.scheduleChunk(chunk)
                aligner?.appendChunk(chunk)
                chunksBuffered += 1

                if chunksBuffered == prebufferCount {
                    player.play()
                    state = .playing
                    delegate?.speechEngine(self, didChangeState: .playing)
                    startDisplayLink()
                }
            }

            if chunksBuffered < prebufferCount {
                player.play()
                state = .playing
                delegate?.speechEngine(self, didChangeState: .playing)
                startDisplayLink()
            }
            aligner?.finishAudio()

            // Wait for final aligned timings, then lock them in.
            let realDuration = player.totalDuration
            if let aligner, aligner.isAvailable {
                await aligner.awaitCompletion(timeout: 3.0)
                let alignedTimings = aligner.timings
                if !alignedTimings.isEmpty {
                    Log.tts.info("Final aligned timings: \(alignedTimings.count) words")
                    finalTimings = alignedTimings
                } else if realDuration > 0 {
                    Log.tts.info("Aligner empty, using duration heuristic (\(realDuration, privacy: .public)s)")
                    finalTimings = WordTimingEstimator.estimate(words: words, totalDuration: realDuration)
                }
            } else if realDuration > 0 {
                Log.tts.info("Aligner unavailable, using duration heuristic (\(realDuration, privacy: .public)s)")
                finalTimings = WordTimingEstimator.estimate(words: words, totalDuration: realDuration)
            }

            player.scheduleEnd { [weak self] in
                Task { @MainActor in
                    self?.handleFinished()
                }
            }
        } catch {
            handleEngineError(error)
        }
    }

    public func pause() {
        audioPlayer?.pause()
        stopDisplayLink()
        state = .paused
        delegate?.speechEngine(self, didChangeState: .paused)
    }

    public func resume() {
        audioPlayer?.resume()
        startDisplayLink()
        state = .playing
        delegate?.speechEngine(self, didChangeState: .playing)
    }

    public func stop() {
        stopDisplayLink()
        audioPlayer?.stop()
        aligner = nil
        state = .idle
        delegate?.speechEngine(self, didChangeState: .idle)
    }

    public func setSpeed(_ speed: Float) {
        guard originalSpeed > 0 else { return }
        audioPlayer?.playbackRate = speed / originalSpeed
    }

    // MARK: - Display link for word tracking

    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateWordHighlight()
            }
        }
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func updateWordHighlight() {
        guard case .playing = state else { return }
        let currentTime = audioPlayer?.currentTime ?? 0

        // Priority: final timings > progressive aligner timings > cadence heuristic
        let activeTimings: [WordTiming]
        if let final = finalTimings {
            activeTimings = final
        } else if let partial = aligner?.timings, !partial.isEmpty {
            activeTimings = partial
        } else {
            activeTimings = cadenceTimings
        }

        let index = WordTimingEstimator.wordIndex(at: currentTime, in: activeTimings)
        delegate?.speechEngine(self, didUpdateWordIndex: index)
    }

    private func handleFinished() {
        stopDisplayLink()
        aligner = nil
        state = .finished
        delegate?.speechEngineDidFinish(self)
    }

    func handleEngineError(_ error: Error) {
        if let ttsError = error as? TTSService.TTSError, ttsError.statusCode == 401 {
            NotificationCenter.default.post(
                name: .voxClawOpenAIAuthFailed,
                object: nil,
                userInfo: [VoxClawNotificationUserInfo.openAIAuthErrorMessage: ttsError.message]
            )
        }
        Log.tts.error("OpenAI engine error: \(error)")
        state = .error(error.localizedDescription)
        delegate?.speechEngine(self, didEncounterError: error)
    }
}
