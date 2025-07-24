//
//  OfflineCacheAPI.swift
//  AIKO
//
//  Extended API for offline cache management
//

import AppCore
import Combine
import Foundation
import os.log

/// Sendable export data type
typealias SendableExportData = [String: [String: any Sendable]]

/// Extended API for cache management operations
extension OfflineCacheManager {
    // MARK: - Search and Query API

    /// Search cache entries by pattern
    /// - Parameters:
    ///   - pattern: Search pattern (supports wildcards)
    ///   - contentTypes: Filter by content types
    ///   - dateRange: Filter by date range
    /// - Returns: Matching cache entries
    func search(
        pattern: String,
        contentTypes: [CacheContentType]? = nil,
        dateRange: DateInterval? = nil
    ) async -> [CacheSearchResult] {
        logger.debug("Searching cache with pattern: \(pattern)")

        var results: [CacheSearchResult] = []

        // Get all keys from all caches
        let allKeys = await getAllKeys()

        // Filter by pattern
        let matchingKeys = allKeys.filter { key in
            matchesPattern(key, pattern: pattern)
        }

        // Get metadata for matching keys
        for key in matchingKeys {
            if let metadata = await getCacheMetadata(forKey: key) {
                // Apply filters
                if let types = contentTypes, !types.contains(metadata.contentType) {
                    continue
                }

                if let range = dateRange {
                    if metadata.createdAt < range.start || metadata.createdAt > range.end {
                        continue
                    }
                }

                results.append(CacheSearchResult(
                    key: key,
                    metadata: metadata,
                    location: getCacheLocation(forKey: key)
                ))
            }
        }

        return results
    }

    /// Get cache metadata for a key
    func getCacheMetadata(forKey key: String) async -> OfflineCacheMetadata? {
        // Try to get metadata from each cache
        if let metadata = await memoryCache.getMetadata(forKey: key) {
            return metadata
        }

        if let metadata = await diskCache.getMetadata(forKey: key) {
            return metadata
        }

        if let metadata = await secureCache.getMetadata(forKey: key) {
            return metadata
        }

        return nil
    }

    // MARK: - Batch Operations API

    /// Store multiple items in batch
    /// - Parameters:
    ///   - items: Array of items to store
    ///   - progressHandler: Optional progress callback
    /// - Returns: Results for each item
    @discardableResult
    func batchStore(
        _ items: [(key: String, object: some Codable & Sendable, type: CacheContentType, isSecure: Bool)],
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> [BatchOperationResult] {
        logger.info("Batch storing \(items.count) items")

        var results: [BatchOperationResult] = []
        let total = Double(items.count)

        for (index, item) in items.enumerated() {
            do {
                try await store(item.object, forKey: item.key, type: item.type, isSecure: item.isSecure)
                results.append(BatchOperationResult(key: item.key, success: true, error: nil))
            } catch {
                results.append(BatchOperationResult(key: item.key, success: false, error: error))
            }

            progressHandler?(Double(index + 1) / total)
        }

        return results
    }

    /// Retrieve multiple items in batch
    func batchRetrieve<T: Codable & Sendable>(
        _ type: T.Type,
        keys: [String],
        isSecure: Bool = false
    ) async -> [String: T?] {
        logger.debug("Batch retrieving \(keys.count) items")

        var results: [String: T?] = [:]

        await withTaskGroup(of: (String, T?).self) { group in
            for key in keys {
                group.addTask {
                    let value = try? await self.retrieve(type, forKey: key, isSecure: isSecure)
                    return (key, value)
                }
            }

            for await (key, value) in group {
                results[key] = value
            }
        }

        return results
    }

    /// Remove multiple items in batch
    func batchRemove(keys: [String]) async throws {
        logger.info("Batch removing \(keys.count) items")

        for key in keys {
            try await remove(forKey: key)
        }
    }

    // MARK: - Cache Health and Monitoring API

    /// Get cache health status
    func healthCheck() async -> CacheHealthStatus {
        let memoryHealth = await memoryCache.checkHealth()
        let diskHealth = await diskCache.checkHealth()
        let secureHealth = await secureCache.checkHealth()

        let totalSize = await totalSize()
        let sizePercentage = Double(totalSize) / Double(configuration.maxSize)

        let isHealthy = memoryHealth.level == .healthy && diskHealth.level == .healthy && secureHealth.level == .healthy
        
        let overallHealth: CacheHealthStatus.HealthLevel = if isHealthy && sizePercentage < 0.9 {
            .healthy
        } else if sizePercentage > 0.95 {
            .critical
        } else {
            .warning
        }

        return CacheHealthStatus(
            level: overallHealth,
            totalSize: totalSize,
            maxSize: configuration.maxSize,
            entryCount: statistics.entryCount,
            hitRate: calculateHitRate(),
            lastCleanup: statistics.lastCleanup,
            issues: identifyHealthIssues()
        )
    }

    /// Monitor cache performance
    func startMonitoring(interval: TimeInterval = 60) -> AnyPublisher<CachePerformanceMetrics, Never> {
        Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .map { _ in
                CachePerformanceMetrics(
                    hitRate: self.calculateHitRate(),
                    averageRetrievalTime: self.statistics.averageRetrievalTime,
                    averageStorageTime: self.statistics.averageStorageTime,
                    memoryPressure: self.getMemoryPressure(),
                    diskUsage: self.getDiskUsage()
                )
            }
            .eraseToAnyPublisher()
    }

    // MARK: - Import/Export API

    /// Export cache contents to a file
    /// - Parameters:
    ///   - url: Destination URL
    ///   - options: Export options
    /// - Returns: Export summary
    func exportCache(to url: URL, options: CacheExportOptions = .default) async throws -> CacheExportSummary {
        logger.info("Exporting cache to: \(url.path)")

        var exportData: [String: Any] = [:]
        var exportedCount = 0

        // Collect data based on options
        if options.includeMemoryCache {
            let memoryData = await memoryCache.exportAllData()
            exportData["memory"] = memoryData
            exportedCount += memoryData.count
        }

        if options.includeDiskCache {
            let diskData = await diskCache.exportAllData()
            exportData["disk"] = diskData
            exportedCount += diskData.count
        }

        if options.includeSecureCache, options.includeSecureData {
            let secureData = await secureCache.exportAllData()
            exportData["secure"] = secureData
            exportedCount += secureData.count
        }

        // Add metadata
        exportData["metadata"] = try [
            "exportDate": Date(),
            "version": "1.0",
            "configuration": JSONEncoder().encode(configuration),
        ]

        // Write to file
        let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
        try jsonData.write(to: url)

        return CacheExportSummary(
            exportedEntries: exportedCount,
            fileSize: jsonData.count,
            exportDate: Date()
        )
    }

    /// Import cache contents from a file
    /// - Parameters:
    ///   - url: Source URL
    ///   - options: Import options
    /// - Returns: Import summary
    func importCache(from url: URL, options: CacheImportOptions = .default) async throws -> CacheImportSummary {
        logger.info("Importing cache from: \(url.path)")

        let data = try Data(contentsOf: url)
        let importData = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        var importedCount = 0
        var failedCount = 0

        // Import based on options
        if options.importMemoryCache, let memoryData = importData["memory"] as? [String: Data] {
            for (key, data) in memoryData {
                do {
                    try await memoryCache.storeData(data, forKey: key)
                    importedCount += 1
                } catch {
                    failedCount += 1
                    logger.error("Failed to import key \(key): \(error.localizedDescription)")
                }
            }
        }

        if options.importDiskCache, let diskData = importData["disk"] as? [String: Data] {
            for (key, data) in diskData {
                do {
                    try await diskCache.storeData(data, forKey: key)
                    importedCount += 1
                } catch {
                    failedCount += 1
                }
            }
        }

        return CacheImportSummary(
            importedEntries: importedCount,
            failedEntries: failedCount,
            importDate: Date()
        )
    }

    // MARK: - Priority-based Caching API

    /// Store with priority
    func storeWithPriority(
        _ object: some Codable & Sendable,
        forKey key: String,
        type: CacheContentType,
        priority: CachePriority,
        isSecure: Bool = false
    ) async throws {
        // Add priority metadata
        var metadata = OfflineCacheMetadata(
            key: key,
            size: 0, // Will be calculated
            contentType: type,
            createdAt: Date(),
            lastAccessed: Date(),
            accessCount: 0,
            expiresAt: nil
        )
        metadata.priority = priority

        // Store with priority consideration
        try await store(object, forKey: key, type: type, isSecure: isSecure)

        // Update metadata
        await updateMetadata(metadata, forKey: key)
    }

    /// Pre-load high priority items
    func preloadHighPriorityItems() async {
        logger.info("Pre-loading high priority items")

        let highPriorityKeys = await getKeysByPriority(.high)

        for key in highPriorityKeys {
            // Ensure it's in memory cache
            if await memoryCache.exists(forKey: key) {
                continue
            }

            // Load from disk/secure cache
            if let data = try? await diskCache.retrieveData(forKey: key) {
                try? await memoryCache.storeData(data, forKey: key)
            } else if let data = try? await secureCache.retrieveData(forKey: key) {
                try? await memoryCache.storeData(data, forKey: key)
            }
        }
    }

    // MARK: - Synchronization API

    /// Get synchronization status
    func getSyncStatus() -> CacheSyncStatus {
        CacheSyncStatus(
            lastSync: statistics.lastSync,
            pendingChanges: statistics.pendingChanges,
            isSyncing: statistics.isSyncing,
            syncErrors: statistics.syncErrors
        )
    }

    /// Mark items for synchronization
    func markForSync(keys: [String]) async {
        for key in keys {
            await markKeyForSync(key)
        }

        statistics.pendingChanges = keys.count
    }

    /// Get items pending synchronization
    func getPendingSyncItems() async -> [String] {
        // Implementation would track which items need syncing
        []
    }

    // MARK: - Advanced Configuration API

    /// Update cache configuration
    func updateConfiguration(_: OfflineCacheConfiguration) async {
        logger.info("Updating cache configuration")

        // This would require rebuilding caches with new config
        // For now, log the intent
        logger.warning("Configuration update not fully implemented")
    }

    /// Get detailed cache analytics
    func getAnalytics() async -> CacheAnalytics {
        let patterns = await analyzeAccessPatterns()
        let sizeDistribution = await analyzeSizeDistribution()
        let typeDistribution = await analyzeTypeDistribution()

        return CacheAnalytics(
            accessPatterns: patterns,
            sizeDistribution: sizeDistribution,
            typeDistribution: typeDistribution,
            performanceMetrics: CachePerformanceMetrics(
                hitRate: calculateHitRate(),
                averageRetrievalTime: statistics.averageRetrievalTime,
                averageStorageTime: statistics.averageStorageTime,
                memoryPressure: getMemoryPressure(),
                diskUsage: getDiskUsage()
            )
        )
    }

    // MARK: - Helper Methods

    private func matchesPattern(_ key: String, pattern: String) -> Bool {
        // Simple wildcard matching
        let regexPattern = pattern
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        return key.range(of: regexPattern, options: .regularExpression) != nil
    }

    private func getCacheLocation(forKey _: String) -> CacheLocation {
        // This would need async handling to determine location
        // For now, return none - proper implementation would track this
        .none
    }

    private func calculateHitRate() -> Double {
        let total = statistics.hitCount + statistics.missCount
        guard total > 0 else { return 0 }
        return Double(statistics.hitCount) / Double(total)
    }

    private func getMemoryPressure() -> Double {
        // Simplified memory pressure calculation
        // This would need proper async handling to get actual memory size
        0.5
    }

    private func getDiskUsage() -> Double {
        // Simplified disk usage calculation
        Double(statistics.totalSize) / Double(configuration.maxSize)
    }

    private func identifyHealthIssues() -> [String] {
        var issues: [String] = []

        if getDiskUsage() > 0.9 {
            issues.append("Cache size approaching limit")
        }

        if calculateHitRate() < 0.5 {
            issues.append("Low cache hit rate")
        }

        if let lastCleanup = statistics.lastCleanup,
           Date().timeIntervalSince(lastCleanup) > 86400 * 7
        {
            issues.append("Cache cleanup overdue")
        }

        return issues
    }

    private func updateMetadata(_: OfflineCacheMetadata, forKey _: String) async {
        // Implementation would update metadata in the appropriate cache
    }

    private func getKeysByPriority(_: CachePriority) async -> [String] {
        // Implementation would filter keys by priority
        []
    }

    private func markKeyForSync(_: String) async {
        // Implementation would mark key for synchronization
    }

    private func analyzeAccessPatterns() async -> [AccessPattern] {
        // Implementation would analyze access patterns
        []
    }

    private func analyzeSizeDistribution() async -> SizeDistribution {
        // Implementation would analyze size distribution
        SizeDistribution(small: 0, medium: 0, large: 0)
    }

    private func analyzeTypeDistribution() async -> [CacheContentType: Int] {
        // Implementation would analyze type distribution
        [:]
    }
}

// MARK: - Supporting Types

struct CacheSearchResult {
    let key: String
    let metadata: OfflineCacheMetadata
    let location: CacheLocation
}

enum CacheLocation {
    case memory
    case disk
    case secure
    case none
}

struct BatchOperationResult {
    let key: String
    let success: Bool
    let error: Error?
}

struct CacheHealthStatus {
    let level: HealthLevel
    let totalSize: Int64
    let maxSize: Int64
    let entryCount: Int
    let hitRate: Double
    let lastCleanup: Date?
    let issues: [String]

    enum HealthLevel {
        case healthy
        case warning
        case critical
    }
}

struct CachePerformanceMetrics {
    let hitRate: Double
    let averageRetrievalTime: TimeInterval
    let averageStorageTime: TimeInterval
    let memoryPressure: Double
    let diskUsage: Double
}

struct CacheExportOptions {
    let includeMemoryCache: Bool
    let includeDiskCache: Bool
    let includeSecureCache: Bool
    let includeSecureData: Bool
    let compress: Bool

    static let `default` = CacheExportOptions(
        includeMemoryCache: true,
        includeDiskCache: true,
        includeSecureCache: false,
        includeSecureData: false,
        compress: false
    )
}

struct CacheExportSummary {
    let exportedEntries: Int
    let fileSize: Int
    let exportDate: Date
}

struct CacheImportOptions {
    let importMemoryCache: Bool
    let importDiskCache: Bool
    let importSecureCache: Bool
    let overwriteExisting: Bool

    static let `default` = CacheImportOptions(
        importMemoryCache: true,
        importDiskCache: true,
        importSecureCache: false,
        overwriteExisting: false
    )
}

struct CacheImportSummary {
    let importedEntries: Int
    let failedEntries: Int
    let importDate: Date
}

enum CachePriority: Int, Codable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3
}

struct CacheSyncStatus {
    let lastSync: Date?
    let pendingChanges: Int
    let isSyncing: Bool
    let syncErrors: [String]
}

struct CacheAnalytics {
    let accessPatterns: [AccessPattern]
    let sizeDistribution: SizeDistribution
    let typeDistribution: [CacheContentType: Int]
    let performanceMetrics: CachePerformanceMetrics
}

struct AccessPattern {
    let timeRange: String
    let accessCount: Int
    let mostAccessed: [String]
}

struct SizeDistribution {
    let small: Int // < 1KB
    let medium: Int // 1KB - 1MB
    let large: Int // > 1MB
}

// MARK: - Cache Metadata Extension

extension OfflineCacheMetadata {
    var priority: CachePriority {
        get {
            // Get from stored metadata
            .normal
        }
        set {
            // Store in metadata
        }
    }
}
