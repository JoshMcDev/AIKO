//
//  SecureCache.swift
//  AIKO
//
//  Created for offline caching system
//

import AppCore
import CryptoKit
import Foundation
import os.log
import Security

/// Secure cache implementation using Keychain and encryption
public actor SecureCache: OfflineCacheProtocol {
    /// Logger
    private let logger = Logger(subsystem: "com.aiko.cache", category: "SecureCache")

    /// Service identifier for keychain
    private let keychainService = "com.aiko.securecache"
    public let serviceName = "com.aiko.securecache"

    /// Cache configuration
    private let configuration: OfflineCacheConfiguration

    /// Metadata tracking (stored separately from secure data)
    private var metadata: [String: SecureCacheMetadata] = [:]

    /// Encryption key
    private let encryptionKey: SymmetricKey

    /// Initialize with configuration
    public init(configuration: OfflineCacheConfiguration) {
        self.configuration = configuration

        // Generate or retrieve encryption key
        if let existingKey = Self.loadEncryptionKey() {
            encryptionKey = existingKey
        } else {
            encryptionKey = SymmetricKey(size: .bits256)
            Self.saveEncryptionKey(encryptionKey)
        }

        // Load metadata
        Task {
            await self.loadMetadata()
        }
    }

    public func store(_ object: some Codable & Sendable, forKey key: String) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try await storeData(data, forKey: key)
    }

    public func retrieve<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        guard let data = try await retrieveData(forKey: key) else { return nil }

        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    public func storeData(_ data: Data, forKey key: String) async throws {
        // Check metadata for expiration
        if let meta = metadata[key], meta.isExpired {
            try await remove(forKey: key)
        }

        // Encrypt data if configured
        let dataToStore: Data = if configuration.useEncryption {
            try encryptData(data)
        } else {
            data
        }

        // Store in keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: dataToStore,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            // Update metadata
            let meta = SecureCacheMetadata(
                key: key,
                size: Int64(data.count),
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(configuration.defaultExpiration),
                isEncrypted: configuration.useEncryption
            )
            metadata[key] = meta
            await saveMetadata()

            logger.debug("Securely stored \(data.count) bytes for key: \(key)")
        } else {
            logger.error("Keychain error: \(status)")
            throw OfflineCacheError.storageFailure("Keychain error: \(status)")
        }
    }

    public func retrieveData(forKey key: String) async throws -> Data? {
        // Check metadata
        guard var meta = metadata[key] else {
            logger.debug("No metadata for key: \(key)")
            return nil
        }

        // Check expiration
        if meta.isExpired {
            logger.debug("Entry expired for key: \(key)")
            try await remove(forKey: key)
            return nil
        }

        // Retrieve from keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let data = result as? Data {
            // Decrypt if needed
            let decryptedData: Data = if meta.isEncrypted {
                try decryptData(data)
            } else {
                data
            }

            // Update access metadata
            meta.lastAccessedAt = Date()
            meta.accessCount += 1
            metadata[key] = meta
            await saveMetadata()

            logger.debug("Retrieved secure data for key: \(key)")
            return decryptedData
        } else if status == errSecItemNotFound {
            // Remove stale metadata
            metadata.removeValue(forKey: key)
            await saveMetadata()
            return nil
        } else {
            logger.error("Keychain retrieval error: \(status)")
            throw OfflineCacheError.retrievalFailure("Keychain error: \(status)")
        }
    }

    public func remove(forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            metadata.removeValue(forKey: key)
            await saveMetadata()
            logger.debug("Removed secure cache for key: \(key)")
        } else {
            logger.error("Keychain deletion error: \(status)")
            throw OfflineCacheError.storageFailure("Failed to delete keychain item")
        }
    }

    public func clearAll() async throws {
        // Clear all items with our service
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
        ]

        SecItemDelete(query as CFDictionary)

        metadata.removeAll()
        await saveMetadata()

        logger.info("Cleared all secure cache")
    }

    public func size() async -> Int64 {
        metadata.values.reduce(0) { $0 + $1.size }
    }

    public func exists(forKey key: String) async -> Bool {
        guard let meta = metadata[key], !meta.isExpired else { return false }

        // Verify keychain entry exists
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false,
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    public func allKeys() async -> [String] {
        Array(metadata.keys)
    }

    public func setExpiration(_ duration: TimeInterval, forKey key: String) async throws {
        guard var meta = metadata[key] else {
            throw OfflineCacheError.keyNotFound
        }

        meta.expiresAt = Date().addingTimeInterval(duration)
        metadata[key] = meta
        await saveMetadata()
    }

    /// Remove expired entries
    private func removeExpiredEntries() async {
        let expiredKeys = metadata.compactMap { key, meta in
            meta.isExpired ? key : nil
        }

        for key in expiredKeys {
            try? await remove(forKey: key)
        }

        if !expiredKeys.isEmpty {
            logger.debug("Removed \(expiredKeys.count) expired secure entries")
        }
    }
    
    /// Remove expired secure entries (alias)
    public func removeExpiredSecureEntries() async {
        await removeExpiredEntries()
    }
    
    /// Get metadata for a key
    func getMetadata(forKey key: String) async -> OfflineCacheMetadata? {
        guard let meta = metadata[key], !meta.isExpired else { return nil }
        
        return OfflineCacheMetadata(
            key: key,
            size: meta.size,
            contentType: .userData,
            createdAt: meta.createdAt,
            lastAccessed: meta.lastAccessedAt,
            accessCount: meta.accessCount,
            expiresAt: meta.expiresAt
        )
    }
    
    /// Check cache health
    func checkHealth() async -> CacheHealthStatus {
        let totalEntries = metadata.count
        let _ = metadata.values.filter { $0.isExpired }.count
        let totalSize = metadata.values.reduce(0) { $0 + $1.size }
        
        return CacheHealthStatus(
            level: .healthy,
            totalSize: totalSize,
            maxSize: configuration.maxSize,
            entryCount: totalEntries,
            hitRate: 0.0, // TODO: Track actual hit rate
            lastCleanup: Date(),
            issues: []
        )
    }
    
    /// Export all data
    func exportAllData() async -> SendableExportData {
        var exportData: SendableExportData = [:]
        
        for (key, meta) in metadata {
            if !meta.isExpired {
                // For security, we export only metadata, not the actual data
                exportData[key] = [
                    "createdAt": meta.createdAt.timeIntervalSince1970,
                    "lastAccessedAt": meta.lastAccessedAt.timeIntervalSince1970,
                    "expiresAt": meta.expiresAt?.timeIntervalSince1970 ?? 0,
                    "accessCount": meta.accessCount,
                    "size": meta.size,
                    "note": "Data not exported for security reasons"
                ]
            }
        }
        
        return exportData
    }

    /// Encrypt data using AES-GCM
    private func encryptData(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        guard let combined = sealedBox.combined else {
            throw OfflineCacheError.storageFailure("Encryption failed")
        }
        return combined
    }

    /// Decrypt data using AES-GCM
    private func decryptData(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }

    /// Load metadata from UserDefaults
    private func loadMetadata() async {
        let key = "SecureCacheMetadata"
        guard let data = UserDefaults.standard.data(forKey: key) else { return }

        do {
            let decoder = JSONDecoder()
            metadata = try decoder.decode([String: SecureCacheMetadata].self, from: data)
            logger.debug("Loaded secure metadata with \(self.metadata.count) entries")
        } catch {
            logger.error("Failed to load secure metadata: \(error)")
            metadata = [:]
        }
    }

    /// Save metadata to UserDefaults
    private func saveMetadata() async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(metadata)
            UserDefaults.standard.set(data, forKey: "SecureCacheMetadata")
        } catch {
            logger.error("Failed to save secure metadata: \(error)")
        }
    }

    /// Load encryption key from keychain
    private static func loadEncryptionKey() -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.aiko.encryption.key",
            kSecReturnData as String: true,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let keyData = result as? Data {
            return SymmetricKey(data: keyData)
        }

        return nil
    }

    /// Save encryption key to keychain
    private static func saveEncryptionKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.aiko.encryption.key",
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        SecItemDelete(query as CFDictionary) // Delete any existing
        SecItemAdd(query as CFDictionary, nil)
    }
}

/// Metadata for secure cache entries
struct SecureCacheMetadata: Codable {
    let key: String
    let size: Int64
    let createdAt: Date
    var lastAccessedAt: Date
    var expiresAt: Date?
    var accessCount: Int
    let isEncrypted: Bool

    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() > expiresAt
    }

    init(key: String, size: Int64, createdAt: Date, expiresAt: Date?, isEncrypted: Bool) {
        self.key = key
        self.size = size
        self.createdAt = createdAt
        lastAccessedAt = createdAt
        self.expiresAt = expiresAt
        accessCount = 0
        self.isEncrypted = isEncrypted
    }
}
