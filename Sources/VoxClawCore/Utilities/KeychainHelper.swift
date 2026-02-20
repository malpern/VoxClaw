import Foundation
import os
import Security

enum KeychainHelper {
    private static let defaultService = "openai-voice-api-key"
    private static let defaultAccount = "openai"

    enum KeychainError: Error, CustomStringConvertible {
        case notFound
        case unexpectedData
        case osError(OSStatus)

        var description: String {
            switch self {
            case .notFound:
                return "API key not found in Keychain. Add it with:\n  security add-generic-password -a \"openai\" -s \"openai-voice-api-key\" -w \"sk-...\""
            case .unexpectedData:
                return "Unexpected data format in Keychain entry"
            case .osError(let status):
                return "Keychain error: \(status)"
            }
        }
    }

    /// Reads API key, checking the `OPENAI_API_KEY` env var first, then keychain.
    static func readAPIKey() throws -> String {
        // First check environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"].map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }), !envKey.isEmpty {
            Log.keychain.info("API key sourced from OPENAI_API_KEY env var")
            return envKey
        }

        return try readFromKeychain()
    }

    /// Reads API key directly from the keychain, bypassing the env var check.
    static func readFromKeychain(service: String = defaultService, account: String = defaultAccount) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let raw = String(data: data, encoding: .utf8) else {
                Log.keychain.error("Keychain returned unexpected data format")
                throw KeychainError.unexpectedData
            }
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw KeychainError.unexpectedData
            }
            Log.keychain.info("API key sourced from Keychain")
            return key
        case errSecItemNotFound:
            Log.keychain.error("API key not found in Keychain")
            throw KeychainError.notFound
        default:
            Log.keychain.error("Keychain error: status=\(status, privacy: .public)")
            throw KeychainError.osError(status)
        }
    }

    static func saveAPIKey(_ key: String, service: String = defaultService, account: String = defaultAccount) throws {
        guard let data = key.data(using: .utf8) else { return }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data,
        ]
        var status = SecItemAdd(addQuery as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Entry already exists — update it in place
            let searchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account,
                kSecAttrService as String: service,
            ]
            status = SecItemUpdate(searchQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw KeychainError.osError(status)
        }
        Log.keychain.info("API key saved to keychain")
    }

    static func deleteAPIKey(service: String = defaultService, account: String = defaultAccount) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.osError(status)
        }
    }
}
