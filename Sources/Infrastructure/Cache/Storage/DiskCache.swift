import Foundation
import CommonCrypto
import ComposableArchitecture
import AppCore

/// Cache eviction policy
public enum CacheEvictionPolicy: Sendable, Codable {
    case leastRecentlyUsed
    case leastFrequentlyUsed
    case firstInFirstOut
    case timeBasedExpiration
}


/// Disk-based cache implementation with persistence and TTL support
public actor DiskCache: OfflineCacheProtocol {
    // MARK: - Properties
    
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 // bytes
    private let defaultExpiration: TimeInterval
    private let fileManager = FileManager.default
    private var cacheIndex: [String: CacheEntry] = [:]
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Cache Entry
    
    private struct CacheEntry: Codable {
        let key: String
        let fileName: String
        let createdAt: Date
        let expiresAt: Date
        let size: Int64
        let accessCount: Int
        let lastAccessed: Date
        
        var isExpired: Bool {
            Date() > expiresAt
        }
    }
    
    // MARK: - Initialization
    
    public init(
        configuration: OfflineCacheConfiguration? = nil,
        cacheDirectory: URL? = nil,
        maxCacheSize: Int64? = nil,
        defaultExpiration: TimeInterval? = nil
    ) throws {
        let config = configuration ?? .default
        self.maxCacheSize = maxCacheSize ?? config.maxSize
        self.defaultExpiration = defaultExpiration ?? config.defaultExpiration
        
        // Setup cache directory
        if let directory = cacheDirectory {
            self.cacheDirectory = directory
        } else {
            // Use default cache directory
            let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
            guard let cacheDir = urls.first else {
                throw DiskCacheError.invalidCacheDirectory
            }
            self.cacheDirectory = cacheDir.appendingPathComponent("ObjectActionCache")
        }
        
        // Create directory if needed
        try createCacheDirectoryIfNeeded()
        
        // Load existing index and clean expired entries asynchronously
        Task {
            try await self.loadCacheIndexAsync()
            await self.cleanExpiredEntries()
        }
    }
    
    // MARK: - Public Methods
    
    /// Store data in cache (alias for set)
    public func store<T: Codable>(_ object: T, forKey key: String, ttl: TimeInterval? = nil) async throws {
        try await set(key, value: object, ttl: ttl)
    }
    
    /// Store data in cache (protocol conformance)
    public func store<T: Codable & Sendable>(_ object: T, forKey key: String) async throws {
        try await set(key, value: object, ttl: nil)
    }
    
    /// Store data in cache
    public func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval? = nil) async throws {
        let expirationTime = ttl ?? defaultExpiration
        let expiresAt = Date().addingTimeInterval(expirationTime)
        let fileName = generateFileName(for: key)
        let filePath = cacheDirectory.appendingPathComponent(fileName)
        
        // Encode and write data
        let data = try encoder.encode(value)
        try data.write(to: filePath)
        
        // Update index
        let entry = CacheEntry(
            key: key,
            fileName: fileName,
            createdAt: Date(),
            expiresAt: expiresAt,
            size: Int64(data.count),
            accessCount: 0,
            lastAccessed: Date()
        )
        
        cacheIndex[key] = entry
        try saveCacheIndex()
        
        // Enforce size limits
        await enforceMaxCacheSize()
    }
    
    /// Retrieve data from cache
    public func get<T: Codable>(_ key: String, type: T.Type) async throws -> T? {
        guard let entry = cacheIndex[key] else {
            return nil
        }
        
        // Check expiration
        if entry.isExpired {
            await remove(key)
            return nil
        }
        
        let filePath = cacheDirectory.appendingPathComponent(entry.fileName)
        
        guard fileManager.fileExists(atPath: filePath.path) else {
            // File missing, remove from index
            await remove(key)
            return nil
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            let value = try decoder.decode(T.self, from: data)
            
            // Update access count and last accessed time
            var updatedEntry = entry
            updatedEntry = CacheEntry(
                key: entry.key,
                fileName: entry.fileName,
                createdAt: entry.createdAt,
                expiresAt: entry.expiresAt,
                size: entry.size,
                accessCount: entry.accessCount + 1,
                lastAccessed: Date()
            )
            cacheIndex[key] = updatedEntry
            try saveCacheIndex()
            
            return value
        } catch {
            // Corrupted file, remove it
            await remove(key)
            throw DiskCacheError.corruptedData
        }
    }
    
    /// Remove item from cache
    public func remove(_ key: String) async {
        guard let entry = cacheIndex[key] else { return }
        
        let filePath = cacheDirectory.appendingPathComponent(entry.fileName)
        try? fileManager.removeItem(at: filePath)
        cacheIndex.removeValue(forKey: key)
        try? saveCacheIndex()
    }
    
    /// Clear all cache
    public func clear() async throws {
        // Remove all files
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
        
        // Clear index
        cacheIndex.removeAll()
        try saveCacheIndex()
    }
    
    /// Check if key exists and is not expired
    public func contains(_ key: String) async -> Bool {
        guard let entry = cacheIndex[key] else { return false }
        
        if entry.isExpired {
            await remove(key)
            return false
        }
        
        return true
    }
    
    /// Retrieve data from cache (alias for get)
    public func retrieve<T: Codable & Sendable>(_ type: T.Type, forKey key: String) async throws -> T? {
        return try await get(key, type: type)
    }
    
    /// Store raw data in cache
    public func storeData(_ data: Data, forKey key: String) async throws {
        try await storeDataWithTTL(data, forKey: key, ttl: nil)
    }
    
    /// Store raw data in cache with TTL
    public func storeDataWithTTL(_ data: Data, forKey key: String, ttl: TimeInterval? = nil) async throws {
        let expirationTime = ttl ?? defaultExpiration
        let expiresAt = Date().addingTimeInterval(expirationTime)
        let fileName = generateFileName(for: key)
        let filePath = cacheDirectory.appendingPathComponent(fileName)
        
        try data.write(to: filePath)
        
        let entry = CacheEntry(
            key: key,
            fileName: fileName,
            createdAt: Date(),
            expiresAt: expiresAt,
            size: Int64(data.count),
            accessCount: 0,
            lastAccessed: Date()
        )
        
        cacheIndex[key] = entry
        try saveCacheIndex()
        await enforceMaxCacheSize()
    }
    
    /// Retrieve raw data from cache
    public func retrieveData(forKey key: String) async throws -> Data? {
        guard let entry = cacheIndex[key] else {
            return nil
        }
        
        if entry.isExpired {
            await remove(key)
            return nil
        }
        
        let filePath = cacheDirectory.appendingPathComponent(entry.fileName)
        
        guard fileManager.fileExists(atPath: filePath.path) else {
            await remove(key)
            return nil
        }
        
        do {
            let data = try Data(contentsOf: filePath)
            
            // Update access count
            var updatedEntry = entry
            updatedEntry = CacheEntry(
                key: entry.key,
                fileName: entry.fileName,
                createdAt: entry.createdAt,
                expiresAt: entry.expiresAt,
                size: entry.size,
                accessCount: entry.accessCount + 1,
                lastAccessed: Date()
            )
            cacheIndex[key] = updatedEntry
            try saveCacheIndex()
            
            return data
        } catch {
            await remove(key)
            throw DiskCacheError.corruptedData
        }
    }
    
    /// Remove item from cache (alias with different parameter name)
    public func remove(forKey key: String) async throws {
        await remove(key)
    }
    
    /// Clear all cache (alias)
    public func clearAll() async throws {
        try await clear()
    }
    
    /// Get cache size in bytes
    public func size() async -> Int64 {
        return cacheIndex.values.reduce(0) { $0 + $1.size }
    }
    
    /// Get all cache keys
    public func allKeys() async -> [String] {
        return Array(cacheIndex.keys)
    }
    
    /// Remove expired entries
    public func removeExpiredDiskEntries() async {
        await cleanExpiredEntries()
    }
    
    /// Check if entry exists
    public func exists(forKey key: String) async -> Bool {
        return await contains(key)
    }
    
    /// Set expiration for a key
    public func setExpiration(_ duration: TimeInterval, forKey key: String) async throws {
        guard let entry = cacheIndex[key] else {
            throw OfflineCacheError.keyNotFound
        }
        
        let updatedEntry = CacheEntry(
            key: entry.key,
            fileName: entry.fileName,
            createdAt: entry.createdAt,
            expiresAt: Date().addingTimeInterval(duration),
            size: entry.size,
            accessCount: entry.accessCount,
            lastAccessed: entry.lastAccessed
        )
        
        cacheIndex[key] = updatedEntry
        try saveCacheIndex()
    }
    
    /// Get cache statistics
    public func getStatistics() -> DiskCacheStatistics {
        let totalSize = cacheIndex.values.reduce(0) { $0 + $1.size }
        let entryCount = cacheIndex.count
        let expiredCount = cacheIndex.values.filter { $0.isExpired }.count
        
        return DiskCacheStatistics(
            entryCount: entryCount,
            totalSize: totalSize,
            expiredCount: expiredCount,
            hitRate: calculateHitRate()
        )
    }
    
    // MARK: - Private Methods
    
    private nonisolated func createCacheDirectoryIfNeeded() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: cacheDirectory.path) {
            try fm.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func generateFileName(for key: String) -> String {
        // Create a safe filename using SHA-256 hash
        let data = key.data(using: .utf8) ?? Data()
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        _ = data.withUnsafeBytes { bytes in
            CC_SHA256(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(data.count), &digest)
        }
        
        let hexString = digest.map { String(format: "%02x", $0) }.joined()
        return "\(hexString).cache"
    }
    
    private func loadCacheIndexAsync() async throws {
        let indexPath = cacheDirectory.appendingPathComponent("index.json")
        
        guard fileManager.fileExists(atPath: indexPath.path) else {
            // No existing index
            return
        }
        
        do {
            let data = try Data(contentsOf: indexPath)
            cacheIndex = try decoder.decode([String: CacheEntry].self, from: data)
        } catch {
            // Corrupted index, start fresh
            cacheIndex = [:]
        }
    }
    
    private func saveCacheIndex() throws {
        let indexPath = cacheDirectory.appendingPathComponent("index.json")
        let data = try encoder.encode(cacheIndex)
        try data.write(to: indexPath)
    }
    
    private func cleanExpiredEntries() async {
        let expiredKeys = cacheIndex.compactMap { key, entry in
            entry.isExpired ? key : nil
        }
        
        for key in expiredKeys {
            await remove(key)
        }
    }
    
    private func enforceMaxCacheSize() async {
        let totalSize = cacheIndex.values.reduce(0) { $0 + $1.size }
        
        guard totalSize > maxCacheSize else { return }
        
        // Sort by least recently used
        let sortedEntries = cacheIndex.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        
        var currentSize = totalSize
        for (key, entry) in sortedEntries {
            if currentSize <= maxCacheSize * 8 / 10 { // Remove until 80% of max size
                break
            }
            
            await remove(key)
            currentSize -= entry.size
        }
    }
    
    /// Get metadata for a key
    func getMetadata(forKey key: String) async -> OfflineCacheMetadata? {
        guard let entry = cacheIndex[key], !entry.isExpired else { return nil }
        
        return OfflineCacheMetadata(
            key: key,
            size: entry.size,
            contentType: .document,
            createdAt: entry.createdAt,
            lastAccessed: entry.lastAccessed,
            accessCount: entry.accessCount,
            expiresAt: entry.expiresAt
        )
    }
    
    /// Check cache health
    func checkHealth() async -> CacheHealthStatus {
        let totalEntries = cacheIndex.count
        let _ = cacheIndex.values.filter { $0.isExpired }.count
        let totalSize = cacheIndex.values.reduce(0) { $0 + $1.size }
        
        return CacheHealthStatus(
            level: .healthy,
            totalSize: totalSize,
            maxSize: maxCacheSize,
            entryCount: totalEntries,
            hitRate: 0.0, // Calculate if needed
            lastCleanup: Date(),
            issues: []
        )
    }
    
    /// Export all data
    func exportAllData() async -> SendableExportData {
        var exportData: SendableExportData = [:]
        
        for (key, entry) in cacheIndex {
            if !entry.isExpired {
                let filePath = cacheDirectory.appendingPathComponent(entry.fileName)
                if let data = try? Data(contentsOf: filePath) {
                    exportData[key] = [
                        "data": data.base64EncodedString(),
                        "createdAt": entry.createdAt.timeIntervalSince1970,
                        "lastAccessedAt": entry.lastAccessed.timeIntervalSince1970,
                        "expiresAt": entry.expiresAt.timeIntervalSince1970,
                        "accessCount": entry.accessCount,
                        "size": entry.size
                    ]
                }
            }
        }
        
        return exportData
    }
    
    private func calculateHitRate() -> Double {
        let totalAccesses = cacheIndex.values.reduce(0) { $0 + $1.accessCount }
        return totalAccesses > 0 ? Double(cacheIndex.count) / Double(totalAccesses) : 0.0
    }
}

// MARK: - Supporting Types

public struct DiskCacheStatistics {
    public let entryCount: Int
    public let totalSize: Int64
    public let expiredCount: Int
    public let hitRate: Double
    
    public var totalSizeMB: Double {
        Double(totalSize) / (1024 * 1024)
    }
}

public enum DiskCacheError: Error, LocalizedError {
    case invalidCacheDirectory
    case corruptedData
    case fileSystemError
    
    public var errorDescription: String? {
        switch self {
        case .invalidCacheDirectory:
            return "Invalid cache directory"
        case .corruptedData:
            return "Corrupted cache data"
        case .fileSystemError:
            return "File system error"
        }
    }
}

// MARK: - Dependency Registration

extension DiskCache: DependencyKey {
    public static var liveValue: DiskCache {
        do {
            return try DiskCache()
        } catch {
            fatalError("Failed to initialize DiskCache: \(error)")
        }
    }
}

public extension DependencyValues {
    var diskCache: DiskCache {
        get { self[DiskCache.self] }
        set { self[DiskCache.self] = newValue }
    }
}