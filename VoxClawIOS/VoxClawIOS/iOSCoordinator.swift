import AVFoundation
import SwiftUI
import UIKit
import UserNotifications
import VoxClawCore

@Observable
@MainActor
final class iOSCoordinator: SpeechQueueDelegate {
    private var networkListener: VoxClawCore.NetworkListener?
    private var interruptionTask: Task<Void, Never>?
    let queue = SpeechQueueCoordinator()
    let keepAlive = BackgroundAudioKeepAlive()
    let peerBrowser = PeerBrowser()
    let cloudRelay = CloudSpeechRelay()

    /// Human-readable CloudKit relay diagnostics, surfaced in Settings so the
    /// state is visible on-device (the unified log isn't always reachable).
    var cloudRelayStatus = "not started"

    /// Watermark for CloudKit relay dedup; persisted so a freshly-launched (push-
    /// woken) process doesn't replay already-spoken requests.
    private static let lastCloudFetchKey = "lastCloudSpeechFetch"

    func startListening(appState: AppState, settings: SettingsManager) {
        stopListening()
        queue.delegate = self
        startDrivingLiveActivity(appState: appState)
        peerBrowser.start()
        let port = settings.networkListenerPort
        let listener = VoxClawCore.NetworkListener(port: port, appState: appState, settings: settings)
        do {
            try listener.start(
                onReadRequest: { [weak self] request in
                    await MainActor.run {
                        guard let self else { return }
                        self.keepAlive.resetTimeout()
                        self.configureAudioSession()
                        UIApplication.shared.isIdleTimerDisabled = true
                        // A relayed request carries the sender's resolved voice/engine —
                        // honor them so the agent sounds the same here as on the source.
                        let engineOverride: (any SpeechEngine)? = request.relayed
                            ? settings.makeRelayEngine(engine: request.engine ?? settings.voiceEngine, voice: request.voice)
                            : nil
                        self.queue.enqueue(
                            request.text,
                            appState: appState,
                            settings: settings,
                            engineOverride: engineOverride,
                            projectId: request.projectId,
                            agentId: request.agentId,
                            requestedEngine: request.engine
                        )
                    }
                },
                onAck: { [weak self] ack in
                    await MainActor.run {
                        self?.queue.handleAck(projectId: ack.projectId, agentId: ack.agentId, appState: appState)
                    }
                },
                onControl: { [weak self] control in
                    await MainActor.run {
                        self?.queue.handleControl(control, deviceID: "ios-\(UIDevice.current.name)")
                    }
                }
            )
            self.networkListener = listener
        } catch {
            print("Failed to start listener: \(error)")
        }
    }

    func stopListening() {
        networkListener?.stop()
        networkListener = nil
    }

    func readText(_ text: String, appState: AppState, settings: SettingsManager) async {
        keepAlive.resetTimeout()
        configureAudioSession()
        UIApplication.shared.isIdleTimerDisabled = true
        queue.enqueue(text, appState: appState, settings: settings)
    }

    // MARK: - CloudKit relay (wake-and-speak)

    /// Registers the CloudKit silent-push subscription so this device wakes when
    /// the Mac relays speech. Seeds the dedup watermark to "now" on first enable
    /// so historical requests aren't replayed. Safe to call repeatedly.
    func ensureCloudRelay(settings: SettingsManager) async {
        guard settings.cloudRelayEnabled else { cloudRelayStatus = "relay off"; return }
        if UserDefaults.standard.object(forKey: Self.lastCloudFetchKey) == nil {
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastCloudFetchKey)
        }
        // Permission to show the spoken text on the lock screen (a Live Activity
        // can't be started from a background wake; a local notification can).
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
        let account = await cloudRelay.accountStatusDescription()
        cloudRelayStatus = "iCloud: \(account) · subscribing…"
        do {
            try await cloudRelay.ensureSubscription()
            cloudRelayStatus = "iCloud: \(account) · subscribed ✓"
        } catch {
            cloudRelayStatus = "iCloud: \(account) · subscribe failed: \(error.localizedDescription)"
            print("CloudKit subscription failed: \(error)")
        }
    }

    /// Called when a CloudKit silent push wakes the app: fetch any speech
    /// requests newer than the watermark and speak them.
    func handleCloudWake(appState: AppState, settings: SettingsManager) async {
        guard settings.cloudRelayEnabled else { return }
        // Drive the Live Activity from here too: when the push wakes us in the
        // background, the SwiftUI scene isn't active, so its observers never fire.
        startDrivingLiveActivity(appState: appState)
        let watermark = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Self.lastCloudFetchKey))
        do {
            let pending = try await cloudRelay.fetchPending(since: watermark)
            let received = pending.first.map { "\($0.engine?.rawValue ?? "?")/\($0.voice ?? "nil")" } ?? "—"
            cloudRelayStatus = "woke \(Date.now.formatted(date: .omitted, time: .standard)) · \(pending.count) pending · rx \(received)"
            guard !pending.isEmpty else { return }
            keepAlive.resetTimeout()
            configureAudioSession()
            UIApplication.shared.isIdleTimerDisabled = true
            for payload in pending {
                // Speak with the engine + voice the sender resolved for this agent,
                // so the agent sounds identical across devices.
                let engine = settings.makeRelayEngine(
                    engine: payload.engine ?? settings.voiceEngine,
                    voice: payload.voice
                )
                queue.enqueue(
                    payload.text,
                    appState: appState,
                    settings: settings,
                    engineOverride: engine,
                    projectId: payload.projectId,
                    agentId: payload.agentId,
                    requestedEngine: payload.engine
                )
                postLockScreenText(payload.text)
            }
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastCloudFetchKey)
        } catch {
            print("CloudKit fetch failed: \(error)")
        }
    }

    /// Shows the spoken text on the lock screen via a local notification. Posted
    /// from the background wake (where a Live Activity can't be started). When the
    /// app is foreground, iOS suppresses the banner by default, so it isn't noisy.
    private func postLockScreenText(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = "VoxClaw"
        content.body = text
        content.sound = nil
        content.interruptionLevel = .active
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Live Activity

    private var liveActivityObserving = false
    private var liveActivityWasActive = false

    /// Drives the "Now reading" Live Activity from non-UI code, so it appears even
    /// when the app was woken in the background by a relay push (locked phone) —
    /// the SwiftUI view's observers don't run in that case. Idempotent.
    func startDrivingLiveActivity(appState: AppState) {
        guard !liveActivityObserving else { return }
        liveActivityObserving = true
        tickLiveActivity(appState: appState)
        observeLiveActivity(appState: appState)
    }

    private func observeLiveActivity(appState: AppState) {
        withObservationTracking {
            _ = appState.queueActive
            _ = appState.currentWordIndex
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.tickLiveActivity(appState: appState)
                self.observeLiveActivity(appState: appState)  // re-arm (one-shot API)
            }
        }
    }

    private func tickLiveActivity(appState: AppState) {
        let active = appState.queueActive
        if active && !liveActivityWasActive {
            LiveActivityController.shared.start(
                snippet: liveActivitySnippet(words: appState.words, index: appState.currentWordIndex),
                title: appState.projectIndicators.first?.name ?? "VoxClaw"
            )
        } else if !active && liveActivityWasActive {
            Task { await LiveActivityController.shared.end() }
        } else if active, appState.words.count > 1 {
            let idx = appState.currentWordIndex
            let snippet = liveActivitySnippet(words: appState.words, index: idx)
            let progress = Double(idx) / Double(appState.words.count - 1)
            Task { await LiveActivityController.shared.update(snippet: snippet, progress: progress) }
        }
        liveActivityWasActive = active
    }

    /// A short window of words around the current position for the Live Activity.
    private func liveActivitySnippet(words: [String], index: Int) -> String {
        guard !words.isEmpty else { return "Reading…" }
        let start = min(max(0, index), words.count - 1)
        let end = min(words.count, start + 8)
        let text = words[start..<end]
            .filter { $0 != ReadingSession.paragraphSentinel }
            .joined(separator: " ")
        return text.isEmpty ? "Reading…" : text
    }

    func togglePause() {
        queue.togglePause()
    }

    func stop() {
        queue.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private let deviceID = "ios-\(UIDevice.current.name)"

    // MARK: - SpeechQueueDelegate

    func makeEngine(for item: SpeechQueueCoordinator.QueueItem, settings: SettingsManager) async -> (any SpeechEngine)? {
        guard item.engineOverride == nil else { return item.engineOverride }
        return settings.createEngine()
    }

    func onControlAction(_ action: HTTPRequestParser.ControlAction) {
        let relayIDs = SettingsManager().activeSpeakers
        guard !relayIDs.isEmpty else { return }
        for peer in peerBrowser.peers {
            guard relayIDs.contains(peer.id), let baseURL = peer.baseURL else { continue }
            guard let url = URL(string: "\(baseURL)/control") else { continue }
            let payload: [String: Any] = ["action": action.rawValue, "origin": deviceID]
            guard let body = try? JSONSerialization.data(withJSONObject: payload) else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
            req.timeoutInterval = 2
            let request = req
            Task.detached { _ = try? await URLSession.shared.data(for: request) }
        }
    }

    // MARK: - Background / Interruptions

    func enterBackground(settings: SettingsManager) {
        #if !APPSTORE
        guard settings.backgroundKeepAlive else { return }
        configureAudioSession()
        keepAlive.start()
        #endif
    }

    func exitBackground() {
        #if !APPSTORE
        keepAlive.stop()
        #endif
    }

    // TODO: For App Store builds, implement push-notification-based wake
    // (APNs or CloudKit push) so the Mac can wake the iOS app when it has
    // speech to relay. This replaces the silent-audio keep-alive which
    // Apple rejects (guideline 2.5.4).

    func observeAudioInterruptions(appState: AppState) {
        interruptionTask?.cancel()
        interruptionTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(named: AVAudioSession.interruptionNotification) {
                guard let self else { return }
                guard let info = notification.userInfo,
                      let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { continue }

                if type == .began {
                    if self.queue.activeSession != nil, !appState.isPaused {
                        self.togglePause()
                    }
                }
            }
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            print("AVAudioSession error: \(error)")
        }
    }
}
