import Foundation
import os
import Security

enum KeychainHelper {
    /// Override for testing — set to a temp directory to isolate from real storage.
    nonisolated(unsafe) static var storageDirectoryOverride: URL?

    private static var storageDirectory: URL {
        if let override = storageDirectoryOverride { return override }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("VoxClaw")
    }

    private static var apiKeyFileURL: URL {
        storageDirectory.appendingPathComponent("api-key")
    }

    enum KeychainError: Error, CustomStringConvertible {
        case notFound
        case unexpectedData
        case fileError(Error)

        var description: String {
            switch self {
            case .notFound:
                return "API key not found. Set it in VoxClaw Settings or via the OPENAI_API_KEY environment variable."
            case .unexpectedData:
                return "Unexpected data format in stored API key"
            case .fileError(let error):
                return "File storage error: \(error.localizedDescription)"
            }
        }
    }

    /// Reads API key, checking the `OPENAI_API_KEY` env var first, then file storage.
    static func readAPIKey() throws -> String {
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }),
           !envKey.isEmpty {
            Log.keychain.info("API key sourced from OPENAI_API_KEY env var")
            return envKey
        }
        return try readPersistedAPIKey()
    }

    /// Reads API key from file storage, migrating from Keychain on first access if needed.
    static func readPersistedAPIKey() throws -> String {
        // 1. Try file storage first
        if let key = readFromFile() {
            return key
        }

        // 2. One-time migration from Keychain (skip when storageDirectoryOverride is set, i.e. tests)
        if storageDirectoryOverride == nil, let key = migrateFromKeychain() {
            return key
        }

        throw KeychainError.notFound
    }

    static func saveAPIKey(_ key: String) throws {
        let dir = storageDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileURL = apiKeyFileURL
        try key.write(to: fileURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
        Log.keychain.info("API key saved to file storage")
    }

    static func deleteAPIKey() throws {
        let fileURL = apiKeyFileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
            Log.keychain.info("API key deleted from file storage")
        }
    }

    // MARK: - File Storage

    private static func readFromFile() -> String? {
        let fileURL = apiKeyFileURL
        guard let data = FileManager.default.contents(atPath: fileURL.path),
              let raw = String(data: data, encoding: .utf8) else {
            return nil
        }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        Log.keychain.info("API key sourced from file storage")
        return key
    }

    // MARK: - One-Time Keychain Migration

    private static let defaultService = "openai-voice-api-key"
    private static let defaultAccount = "openai"

    private struct LegacyKeychainCandidate {
        let service: String
        let preferredAccounts: [String]
    }

    private static let legacyServiceCandidates: [LegacyKeychainCandidate] = [
        LegacyKeychainCandidate(
            service: "openclaw.OPENAI_API_KEY",
            preferredAccounts: ["openai", "openclaw"]
        ),
        LegacyKeychainCandidate(
            service: "OPENAI_API_KEY",
            preferredAccounts: ["openai"]
        ),
    ]

    /// Attempts to read from Keychain (default + legacy locations) and migrate to file storage.
    private static func migrateFromKeychain() -> String? {
        // Try default VoxClaw keychain entry
        if let key = try? readFromKeychain(service: defaultService, account: defaultAccount) {
            try? saveAPIKey(key)
            Log.keychain.info("Migrated API key from Keychain to file storage")
            return key
        }

        // Try legacy service names
        for candidate in legacyServiceCandidates {
            for account in candidate.preferredAccounts {
                if let key = try? readFromKeychain(service: candidate.service, account: account),
                   let normalized = normalizedIfLikelyOpenAIKey(key) {
                    try? saveAPIKey(normalized)
                    Log.keychain.info("Migrated API key from legacy Keychain service \(candidate.service, privacy: .public)")
                    return normalized
                }
            }

            let allKeys = (try? readAllFromKeychain(service: candidate.service)) ?? []
            if let key = uniqueMigrationKey(from: allKeys) {
                try? saveAPIKey(key)
                Log.keychain.info("Migrated unique API key from legacy Keychain service: \(candidate.service, privacy: .public)")
                return key
            }
        }

        return nil
    }

    private static func readFromKeychain(service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let raw = String(data: data, encoding: .utf8) else {
                throw KeychainError.unexpectedData
            }
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { throw KeychainError.unexpectedData }
            return key
        default:
            throw KeychainError.notFound
        }
    }

    private static func readAllFromKeychain(service: String) throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            if let single = result as? Data,
               let raw = String(data: single, encoding: .utf8),
               let key = normalizedIfLikelyOpenAIKey(raw) {
                return [key]
            }
            guard let dataArray = result as? [Data] else {
                throw KeychainError.unexpectedData
            }
            return dataArray.compactMap { data in
                guard let raw = String(data: data, encoding: .utf8) else { return nil }
                return normalizedIfLikelyOpenAIKey(raw)
            }
        default:
            return []
        }
    }

    // MARK: - Helpers

    static func normalizedIfLikelyOpenAIKey(_ raw: String) -> String? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard key.hasPrefix("sk-"), key.count >= 20 else { return nil }
        return key
    }

    static func uniqueMigrationKey(from keys: [String]) -> String? {
        let normalized = keys.compactMap(normalizedIfLikelyOpenAIKey)
        let unique = Set(normalized)
        guard unique.count == 1 else { return nil }
        return unique.first
    }
}
