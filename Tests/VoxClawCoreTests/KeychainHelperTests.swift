import Foundation
@testable import VoxClawCore
import Testing

@Suite(.serialized)
struct KeychainHelperTests {
    /// Each test uses an isolated temp directory via storageDirectoryOverride.
    private let testDir: URL

    init() {
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxclaw-test-\(UUID().uuidString)")
        KeychainHelper.storageDirectoryOverride = testDir
    }

    private func cleanup() {
        try? FileManager.default.removeItem(at: testDir)
        KeychainHelper.storageDirectoryOverride = nil
    }

    /// Save a key, read it back, verify it matches.
    @Test func saveAndReadRoundTrip() throws {
        defer { cleanup() }

        let testKey = "sk-test-roundtrip-\(UUID().uuidString)"
        try KeychainHelper.saveAPIKey(testKey)

        let readBack = try KeychainHelper.readPersistedAPIKey()
        #expect(readBack == testKey)
    }

    /// Saving a second key overwrites the first.
    @Test func saveOverwritesPreviousKey() throws {
        defer { cleanup() }

        try KeychainHelper.saveAPIKey("sk-first-key-value-placeholder")
        try KeychainHelper.saveAPIKey("sk-second-key-value-placeholder")

        let readBack = try KeychainHelper.readPersistedAPIKey()
        #expect(readBack == "sk-second-key-value-placeholder")
    }

    /// Deleting removes the key so the next read throws.
    @Test func deleteRemovesKey() throws {
        defer { cleanup() }

        try KeychainHelper.saveAPIKey("sk-to-delete-key-value-here")
        try KeychainHelper.deleteAPIKey()

        #expect(throws: KeychainHelper.KeychainError.self) {
            try KeychainHelper.readPersistedAPIKey()
        }
    }

    /// Storage directory is created automatically on first save.
    @Test func directoryCreatedAutomatically() throws {
        defer { cleanup() }

        #expect(!FileManager.default.fileExists(atPath: testDir.path))
        try KeychainHelper.saveAPIKey("sk-test-directory-creation-key")
        #expect(FileManager.default.fileExists(atPath: testDir.path))
    }

    /// Saved file has 0600 permissions (owner read/write only).
    @Test func fileHasRestrictedPermissions() throws {
        defer { cleanup() }

        try KeychainHelper.saveAPIKey("sk-test-permissions-check-key")
        let fileURL = testDir.appendingPathComponent("api-key")
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = attributes[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test func normalizeAcceptsLikelyOpenAIKey() {
        let key = "  sk-test-roundtrip-\(UUID().uuidString)  "
        let normalized = KeychainHelper.normalizedIfLikelyOpenAIKey(key)
        #expect(normalized == key.trimmingCharacters(in: .whitespaces))
    }

    @Test func normalizeRejectsNonOpenAIKey() {
        #expect(KeychainHelper.normalizedIfLikelyOpenAIKey("not-a-key") == nil)
        #expect(KeychainHelper.normalizedIfLikelyOpenAIKey("sk-short") == nil)
    }

    @Test func uniqueMigrationKeyRejectsAmbiguousCandidates() {
        let keys = [
            "sk-test-roundtrip-\(UUID().uuidString)",
            "sk-test-roundtrip-\(UUID().uuidString)",
        ]
        #expect(KeychainHelper.uniqueMigrationKey(from: keys) == nil)
    }

    @Test func uniqueMigrationKeyAcceptsSingleUniqueCandidate() {
        let key = "sk-test-roundtrip-\(UUID().uuidString)"
        let keys = [
            key,
            " \(key) ",
            "not-an-openai-key",
        ]
        #expect(KeychainHelper.uniqueMigrationKey(from: keys) == key)
    }
}
