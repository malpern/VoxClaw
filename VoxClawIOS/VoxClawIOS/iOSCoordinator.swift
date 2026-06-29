import AVFoundation
import SwiftUI
import UIKit
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
            }
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastCloudFetchKey)
        } catch {
            print("CloudKit fetch failed: \(error)")
        }
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
