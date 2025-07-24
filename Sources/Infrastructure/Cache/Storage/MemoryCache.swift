//
//  MemoryCache.swift
//  AIKO
//
//  Created for offline caching system
//

import AppCore
import Foundation
import os.log

/// In-memory cache implementation for fast access
actor MemoryCache: OfflineCacheProtocol {
    /// Logger
    private let logger = Logger(subsystem: "com.aiko.cache", category: "MemoryCache")

    /// Cache storage
    var storage: [String: CacheEntry] = [:]

    /// Cache configuration
    let configuration: OfflineCacheConfiguration

    /// Current cache size
    private var currentSize: Int64 = 0

    /// Initialize with configuration
    init(configuration: OfflineCacheConfiguration) {
        self.configuration = configuration
    }

    func store(_ object: some Codable & Sendable, forKey key: String) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try await storeData(data, forKey: key)
    }

    func retrieve<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        guard let data = try await retrieveData(forKey: key) else { return nil }

        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    func storeData(_ data: Data, forKey key: String) async throws {
        // Check if we need to make space
        let newSize = Int64(data.count)
        if currentSize + newSize > configuration.maxSize {
            // Evict entries if needed
            try await makeSpace(for: newSize)
        }

        let entry = CacheEntry(
            key: key,
            data: data,
            contentType: .temporary,
            expiresAt: Date().addingTimeInterval(configuration.defaultExpiration)
        )

        // Remove old entry if exists
        if let oldEntry = storage[key] {
            currentSize -= oldEntry.size
        }

        storage[key] = entry
        currentSize += newSize

        logger.debug("Stored \(newSize) bytes for key: \(key)")
    }

    func retrieveData(forKey key: String) async throws -> Data? {
        guard var entry = storage[key] else {
            logger.debug("Cache miss for key: \(key)")
            return nil
        }

        // Check expiration
        if entry.isExpired {
            logger.debug("Cache entry expired for key: \(key)")
            storage.removeValue(forKey: key)
            currentSize -= entry.size
            return nil
        }

        // Update access metadata
        entry.lastAccessedAt = Date()
        entry.accessCount += 1
        storage[key] = entry

        logger.debug("Cache hit for key: \(key)")
        return entry.data
    }

    func remove(forKey key: String) async throws {
        if let entry = storage.removeValue(forKey: key) {
            currentSize -= entry.size
            logger.debug("Removed entry for key: \(key)")
        }
    }

    func clearAll() async throws {
        storage.removeAll()
        currentSize = 0
        logger.info("Cleared all memory cache")
    }

    func size() async -> Int64 {
        currentSize
    }

    func exists(forKey key: String) async -> Bool {
        if let entry = storage[key] {
            return !entry.isExpired
        }
        return false
    }

    func allKeys() async -> [String] {
        Array(storage.keys)
    }

    func setExpiration(_ duration: TimeInterval, forKey key: String) async throws {
        guard var entry = storage[key] else {
            throw OfflineCacheError.keyNotFound
        }

        entry.expiresAt = Date().addingTimeInterval(duration)
        storage[key] = entry
    }

    /// Remove expired entries
    func removeExpiredEntries() async {
        let expiredKeys = storage.compactMap { key, entry in
            entry.isExpired ? key : nil
        }

        for key in expiredKeys {
            if let entry = storage.removeValue(forKey: key) {
                currentSize -= entry.size
            }
        }

        if !expiredKeys.isEmpty {
            logger.debug("Removed \(expiredKeys.count) expired entries")
        }
    }
    
    /// Remove expired memory entries (alias)
    func removeExpiredMemoryEntries() async {
        await removeExpiredEntries()
    }

    /// Make space for new data
    private func makeSpace(for requiredSize: Int64) async throws {
        // Remove expired entries first
        await removeExpiredEntries()

        // If still not enough space, apply eviction policy
        if currentSize + requiredSize > configuration.maxSize {
            switch configuration.evictionPolicy {
            case .leastRecentlyUsed:
                await evictLRU(targetSize: requiredSize)
            case .leastFrequentlyUsed:
                await evictLFU(targetSize: requiredSize)
            case .firstInFirstOut:
                await evictFIFO(targetSize: requiredSize)
            case .timeBasedExpiration:
                // Already handled by removeExpiredEntries
                break
            }
        }

        // Final check
        if currentSize + requiredSize > configuration.maxSize {
            throw OfflineCacheError.insufficientSpace
        }
    }

    /// Evict least recently used entries
    private func evictLRU(targetSize: Int64) async {
        let sortedEntries = storage.values.sorted { $0.lastAccessedAt < $1.lastAccessedAt }
        var freedSpace: Int64 = 0

        for entry in sortedEntries {
            if currentSize + targetSize - freedSpace <= configuration.maxSize {
                break
            }

            storage.removeValue(forKey: entry.key)
            freedSpace += entry.size
            currentSize -= entry.size
        }
    }

    /// Evict least frequently used entries
    private func evictLFU(targetSize: Int64) async {
        let sortedEntries = storage.values.sorted { $0.accessCount < $1.accessCount }
        var freedSpace: Int64 = 0

        for entry in sortedEntries {
            if currentSize + targetSize - freedSpace <= configuration.maxSize {
                break
            }

            storage.removeValue(forKey: entry.key)
            freedSpace += entry.size
            currentSize -= entry.size
        }
    }

    /// Evict oldest entries first
    private func evictFIFO(targetSize: Int64) async {
        let sortedEntries = storage.values.sorted { $0.createdAt < $1.createdAt }
        var freedSpace: Int64 = 0

        for entry in sortedEntries {
            if currentSize + targetSize - freedSpace <= configuration.maxSize {
                break
            }

            storage.removeValue(forKey: entry.key)
            freedSpace += entry.size
            currentSize -= entry.size
        }
    }
    
    /// Get metadata for a key
    func getMetadata(forKey key: String) async -> OfflineCacheMetadata? {
        guard let entry = storage[key], !entry.isExpired else { return nil }
        
        return OfflineCacheMetadata(
            key: key,
            size: entry.size,
            contentType: entry.contentType,
            createdAt: entry.createdAt,
            lastAccessed: entry.lastAccessedAt,
            accessCount: entry.accessCount,
            expiresAt: entry.expiresAt
        )
    }
    
    /// Check cache health
    func checkHealth() async -> CacheHealthStatus {
        let totalEntries = storage.count
        let _ = storage.values.filter { $0.isExpired }.count
        
        return CacheHealthStatus(
            level: .healthy,
            totalSize: currentSize,
            maxSize: configuration.maxSize,
            entryCount: totalEntries,
            hitRate: 0.0, // Calculate if needed
            lastCleanup: Date(),
            issues: []
        )
    }
    
    /// Export all data
    func exportAllData() async -> SendableExportData {
        var exportData: SendableExportData = [:]
        
        for (key, entry) in storage {
            if !entry.isExpired {
                exportData[key] = [
                    "data": entry.data.base64EncodedString(),
                    "createdAt": entry.createdAt.timeIntervalSince1970,
                    "lastAccessedAt": entry.lastAccessedAt.timeIntervalSince1970,
                    "expiresAt": entry.expiresAt?.timeIntervalSince1970 ?? 0,
                    "accessCount": entry.accessCount,
                    "size": entry.size
                ]
            }
        }
        
        return exportData
    }
}
