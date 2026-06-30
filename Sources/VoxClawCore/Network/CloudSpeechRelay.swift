import Foundation

#if canImport(CloudKit)
import CloudKit
import os

/// Relays agent speech between a user's devices through their private CloudKit
/// database, so a Mac agent can speak on an iPhone that is locked, backgrounded,
/// or on a different network — the cases the LAN `NetworkListener` can't reach.
///
/// Flow: the Mac calls ``send(_:)`` to write a `SpeechRequest` record into a
/// custom zone. CloudKit delivers a silent (content-available) push to the
/// user's other devices via a `CKDatabaseSubscription`; on wake they call
/// ``fetchPending(since:)`` to pull the text and speak it.
///
/// We use a `CKDatabaseSubscription` on a **custom zone** rather than a
/// `CKQuerySubscription`: query subscriptions are unreliable to create in
/// production containers (a long-standing CloudKit issue — "attempting to create
/// a subscription in a production container"), whereas database subscriptions
/// have no predicate/index requirements and create cleanly in production. Database
/// subscriptions only fire for custom zones, so the relay writes to one.
///
/// This complements — does not replace — the LAN path: same-network/foreground
/// delivery still goes through `NetworkListener` for low latency.
public actor CloudSpeechRelay {
    /// Default container; matches the app's `iCloud.<bundle-id>` convention.
    public static let defaultContainerID = "iCloud.com.malpern.voxclaw"
    static let recordType = "SpeechRequest"
    static let subscriptionID = "voxclaw-speech-db"
    static let zoneName = "SpeechRelay"

    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private let log = Logger(subsystem: "com.malpern.voxclaw", category: "CloudSpeechRelay")

    /// Set once the custom zone has been created this session, so steady-state
    /// `send()`/`ensureSubscription()` calls skip the redundant zone-save round-trip.
    private var zoneEnsured = false

    public init(containerID: String = CloudSpeechRelay.defaultContainerID) {
        self.container = CKContainer(identifier: containerID)
        self.database = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// Creates the custom zone the relay uses (idempotent — saving an existing
    /// zone is a no-op). Database subscriptions only fire for custom zones, so
    /// both the sender and the receiver must ensure it exists.
    private func ensureZone() async throws {
        if zoneEnsured { return }
        _ = try await database.save(CKRecordZone(zoneID: zoneID))
        zoneEnsured = true
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
        /// The sender's timestamp for the record. Set on fetch so the receiver can
        /// advance its dedup watermark to the newest record it actually saw,
        /// rather than its own wall clock (which drifts vs the sender).
        public var sentAt: Date?

        public init(
            text: String,
            voice: String? = nil,
            rate: Float? = nil,
            instructions: String? = nil,
            projectId: String? = nil,
            agentId: String? = nil,
            engine: VoiceEngineType? = nil,
            sentAt: Date? = nil
        ) {
            self.text = text
            self.voice = voice
            self.rate = rate
            self.instructions = instructions
            self.projectId = projectId
            self.agentId = agentId
            self.engine = engine
            self.sentAt = sentAt
        }
    }

    // MARK: - Sending (Mac)

    /// Writes a speech request into the relay's custom zone. CloudKit pushes it to
    /// the user's other devices subscribed via ``ensureSubscription()``.
    public func send(_ payload: Payload) async throws {
        try await ensureZone()
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
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

    /// Registers the silent-push database subscription that wakes this device when
    /// any record changes in a custom zone (the relay's `SpeechRelay` zone).
    /// Idempotent: an "already exists" rejection is ignored.
    public func ensureSubscription() async throws {
        try await ensureZone()
        let subscription = CKDatabaseSubscription(subscriptionID: Self.subscriptionID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true   // silent push, no alert/badge/sound
        subscription.notificationInfo = info
        do {
            _ = try await database.save(subscription)
            log.debug("CloudKit database subscription registered")
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Subscription with this ID already exists — fine.
            log.debug("CloudKit database subscription already present")
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
        let (matches, _) = try await database.records(matching: query, inZoneWith: zoneID)
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
                    engine: (record["engine"] as? String).flatMap(VoiceEngineType.init(rawValue:)),
                    sentAt: record["sentAt"] as? Date
                )
            )
        }
        return payloads
    }
}
#endif
