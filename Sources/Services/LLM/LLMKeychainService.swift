import Foundation
import Security

// MARK: - LLM Keychain Error

/// Errors that can occur during keychain operations
public enum LLMKeychainError: Error, LocalizedError {
    case encodingError(String)
    case keychainError(OSStatus)
    case notFound
    case invalidData
    
    public var errorDescription: String? {
        switch self {
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .notFound:
            return "API key not found"
        case .invalidData:
            return "Invalid keychain data"
        }
    }
}

// MARK: - LLM Keychain Service

/// Secure storage for LLM provider API keys using iOS/macOS Keychain
public final class LLMKeychainService: @unchecked Sendable {
    // MARK: - Properties

    public static let shared = LLMKeychainService()

    private let serviceName = "com.aiko.llm"
    private let accessGroup: String? = nil // Set if using app groups

    // MARK: - Public Methods

    /// Store API key for a provider
    public func storeAPIKey(_ key: String, for provider: String) throws {
        let account = accountName(for: provider)
        guard let data = key.data(using: .utf8) else {
            throw LLMKeychainError.encodingError("Failed to encode API key")
        }

        // Check if key already exists
        if (try? retrieveAPIKey(for: provider)) != nil {
            // Update existing key
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account,
            ]

            let attributes: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]

            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

            if status != errSecSuccess {
                throw KeychainError.updateFailed(status)
            }
        } else {
            // Add new key
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]

            if let accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }

            let status = SecItemAdd(query as CFDictionary, nil)

            if status != errSecSuccess {
                throw KeychainError.saveFailed(status)
            }
        }
    }

    /// Retrieve API key for a provider
    public func retrieveAPIKey(for provider: String) throws -> String {
        let account = accountName(for: provider)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.notFound
        }

        return key
    }

    /// Delete API key for a provider
    public func deleteAPIKey(for provider: String) throws {
        let account = accountName(for: provider)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess, status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Check if API key exists for a provider
    public func hasAPIKey(for provider: String) -> Bool {
        do {
            _ = try retrieveAPIKey(for: provider)
            return true
        } catch {
            return false
        }
    }

    /// List all configured providers
    public func listConfiguredProviders() -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]]
        else {
            return []
        }

        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String else { return nil }
            return providerFromAccount(account)
        }
    }

    /// Delete all stored API keys
    public func deleteAllAPIKeys() throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
        ]

        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess, status != errSecItemNotFound {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Private Methods

    private func accountName(for provider: String) -> String {
        "llm_provider_\(provider)"
    }

    private func providerFromAccount(_ account: String) -> String? {
        guard account.hasPrefix("llm_provider_") else { return nil }
        return String(account.dropFirst("llm_provider_".count))
    }
}

// MARK: - Keychain Errors

public enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case updateFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound
    case invalidData

    public var errorDescription: String? {
        switch self {
        case let .saveFailed(status):
            "Failed to save to keychain: \(errorMessage(for: status))"
        case let .updateFailed(status):
            "Failed to update keychain: \(errorMessage(for: status))"
        case let .deleteFailed(status):
            "Failed to delete from keychain: \(errorMessage(for: status))"
        case .notFound:
            "API key not found in keychain"
        case .invalidData:
            "Invalid data in keychain"
        }
    }

    private func errorMessage(for status: OSStatus) -> String {
        if let error = SecCopyErrorMessageString(status, nil) as String? {
            return error
        }
        return "Unknown error (\(status))"
    }
}

// MARK: - Provider Configuration

/// Configuration for an LLM provider including credentials
public struct LLMProviderConfiguration: Equatable, Sendable {
    public let providerId: String
    public let apiKey: String
    public let organizationId: String?
    public let customEndpoint: String?
    public let additionalSettings: [String: String]

    public init(
        providerId: String,
        apiKey: String,
        organizationId: String? = nil,
        customEndpoint: String? = nil,
        additionalSettings: [String: String] = [:]
    ) {
        self.providerId = providerId
        self.apiKey = apiKey
        self.organizationId = organizationId
        self.customEndpoint = customEndpoint
        self.additionalSettings = additionalSettings
    }
}
