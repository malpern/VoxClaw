import Foundation

#if canImport(CloudKit)
import CloudKit
import os

/// Relays agent speech between a user's devices through their private CloudKit
/// database, so a Mac agent can speak on an iPhone that is locked, backgrounded,
/// or on a different network — the cases the LAN `NetworkListener` can't reach.
///
/// Flow: the Mac calls ``send(_:)`` to write a `SpeechRequest` record. CloudKit
/// delivers a silent (content-available) push to the user's other devices via a
/// `CKQuerySubscription`; on wake they call ``fetchPending(since:)`` to pull the
/// text and speak it. The actual text travels in the record (chosen over a
/// wake-only signal so it works off-LAN).
///
/// This complements — does not replace — the LAN path: same-network/foreground
/// delivery still goes through `NetworkListener` for low latency.
public actor CloudSpeechRelay {
    /// Default container; matches the app's `iCloud.<bundle-id>` convention.
    public static let defaultContainerID = "iCloud.com.malpern.voxclaw"
    static let recordType = "SpeechRequest"
    static let subscriptionID = "voxclaw-speech-requests"

    private let container: CKContainer
    private let database: CKDatabase
    private let log = Logger(subsystem: "com.malpern.voxclaw", category: "CloudSpeechRelay")

    public init(containerID: String = CloudSpeechRelay.defaultContainerID) {
        self.container = CKContainer(identifier: containerID)
        self.database = container.privateCloudDatabase
    }

    /// Human-readable iCloud account status for diagnostics ("available",
    /// "noAccount", "restricted", …). The relay can't work unless this is
    /// "available".
    public func accountStatusDescription() async -> String {
        do {
            switch try await container.accountStatus() {
            case .available: return "available"
            case .noAccount: return "noAccount (sign into iCloud)"
            case .restricted: return "restricted"
            case .couldNotDetermine: return "couldNotDetermine"
            case .temporarilyUnavailable: return "temporarilyUnavailable"
            @unknown default: return "unknown"
            }
        } catch {
            return "error: \(error.localizedDescription)"
        }
    }

    // MARK: - Payload

    /// The relayable subset of `ReadRequest`. Mirrors the LAN payload so a relayed
    /// request behaves identically to a local one (minus re-relay, prevented by
    /// marking it `relayed` when handed to the queue).
    public struct Payload: Sendable {
        public let text: String
        public var voice: String?
        public var rate: Float?
        public var instructions: String?
        public var projectId: String?
        public var agentId: String?
        public var engine: VoiceEngineType?

        public init(
            text: String,
            voice: String? = nil,
            rate: Float? = nil,
            instructions: String? = nil,
            projectId: String? = nil,
            agentId: String? = nil,
            engine: VoiceEngineType? = nil
        ) {
            self.text = text
            self.voice = voice
            self.rate = rate
            self.instructions = instructions
            self.projectId = projectId
            self.agentId = agentId
            self.engine = engine
        }
    }

    // MARK: - Sending (Mac)

    /// Writes a speech request to the private database. CloudKit pushes it to the
    /// user's other devices subscribed via ``ensureSubscription()``.
    public func send(_ payload: Payload) async throws {
        let record = CKRecord(recordType: Self.recordType)
        record["text"] = payload.text as CKRecordValue
        if let v = payload.voice { record["voice"] = v as CKRecordValue }
        if let r = payload.rate { record["rate"] = Double(r) as CKRecordValue }
        if let i = payload.instructions { record["instructions"] = i as CKRecordValue }
        if let p = payload.projectId { record["projectId"] = p as CKRecordValue }
        if let a = payload.agentId { record["agentId"] = a as CKRecordValue }
        if let e = payload.engine { record["engine"] = e.rawValue as CKRecordValue }
        record["sentAt"] = Date.now as CKRecordValue
        _ = try await database.save(record)
        log.debug("Relayed speech request to CloudKit (\(payload.text.count) chars)")
    }

    // MARK: - Subscription (iOS receiver)

    /// Registers the silent-push subscription that wakes this device when a new
    /// `SpeechRequest` appears. Idempotent: an "already exists" error is ignored.
    public func ensureSubscription() async throws {
        let subscription = CKQuerySubscription(
            recordType: Self.recordType,
            predicate: NSPredicate(value: true),
            subscriptionID: Self.subscriptionID,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true   // silent push, no alert/badge/sound
        subscription.notificationInfo = info
        do {
            _ = try await database.save(subscription)
            log.debug("CloudKit speech subscription registered")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription with this ID already exists — fine.
            log.debug("CloudKit speech subscription already present")
        }
    }

    // MARK: - Fetching (iOS receiver)

    /// Returns speech requests created after `since`, oldest first, so a woken
    /// device can speak anything it missed. Relies on the queryable `sentAt`
    /// field (the CloudKit schema must index it).
    public func fetchPending(since: Date) async throws -> [Payload] {
        let predicate = NSPredicate(format: "sentAt > %@", since as NSDate)
        let query = CKQuery(recordType: Self.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "sentAt", ascending: true)]
        let (matches, _) = try await database.records(matching: query)
        var payloads: [Payload] = []
        for (_, result) in matches {
            guard case let .success(record) = result, let text = record["text"] as? String else { continue }
            payloads.append(
                Payload(
                    text: text,
                    voice: record["voice"] as? String,
                    rate: (record["rate"] as? Double).map(Float.init),
                    instructions: record["instructions"] as? String,
                    projectId: record["projectId"] as? String,
                    agentId: record["agentId"] as? String,
                    engine: (record["engine"] as? String).flatMap(VoiceEngineType.init(rawValue:))
                )
            )
        }
        return payloads
    }
}
#endif
