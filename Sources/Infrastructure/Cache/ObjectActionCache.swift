import AppCore
import ComposableArchitecture
import Foundation

/// Multi-tier caching system for Object Action Handler optimization
public actor ObjectActionCache {
    // MARK: - Cache Tiers

    /// L1 Cache: Ultra-fast in-memory cache for hot data
    private var l1Cache = LRUCache<CacheKey, CachedAction>(maxSize: 100)

    /// L2 Cache: Larger memory cache with compression
    private var l2Cache = CompressedCache<CacheKey, CachedAction>(maxSize: 1000)

    /// L3 Cache: Disk-based cache for persistent storage
    private nonisolated let l3Cache: any OfflineCacheProtocol

    // MARK: - Cache Configuration

    public struct Configuration: Sendable {
        public let l1MaxSize: Int
        public let l2MaxSize: Int
        public let l3MaxSizeMB: Int
        public let defaultTTL: TimeInterval
        public let compressionEnabled: Bool
        public let warmupEnabled: Bool

        public static let `default` = Configuration(
            l1MaxSize: 100,
            l2MaxSize: 1000,
            l3MaxSizeMB: 100,
            defaultTTL: 3600, // 1 hour
            compressionEnabled: true,
            warmupEnabled: true
        )
    }

    private let configuration: Configuration

    // MARK: - Cache Metrics

    private var metrics = CacheMetrics()

    public struct CacheMetrics: Sendable {
        var l1Hits: Int = 0
        var l1Misses: Int = 0
        var l2Hits: Int = 0
        var l2Misses: Int = 0
        var l3Hits: Int = 0
        var l3Misses: Int = 0
        var totalRequests: Int = 0
        var evictions: Int = 0
        var compressionSavings: Int = 0
        var totalInvalidations: Int = 0
        var totalClears: Int = 0
        var lastClearTime: Date?
        var invalidationDurations: [TimeInterval] = []

        var l1HitRate: Double {
            let total = l1Hits + l1Misses
            return total > 0 ? Double(l1Hits) / Double(total) : 0
        }

        var l2HitRate: Double {
            let total = l2Hits + l2Misses
            return total > 0 ? Double(l2Hits) / Double(total) : 0
        }

        var l3HitRate: Double {
            let total = l3Hits + l3Misses
            return total > 0 ? Double(l3Hits) / Double(total) : 0
        }

        var overallHitRate: Double {
            let hits = l1Hits + l2Hits + l3Hits
            return totalRequests > 0 ? Double(hits) / Double(totalRequests) : 0
        }
    }

    // MARK: - Cache Key

    public struct CacheKey: Hashable, Codable, Sendable {
        let actionType: String
        let objectType: String
        let objectId: String
        let contextHash: String
        let parameters: String // JSON encoded parameters

        init(action: ObjectAction) {
            actionType = action.type.rawValue
            objectType = action.objectType.rawValue
            objectId = action.objectId
            contextHash = action.context.cacheKey

            // Encode parameters as sorted JSON for consistent hashing
            if let data = try? JSONSerialization.data(withJSONObject: action.parameters.sorted(by: { $0.key < $1.key })),
               let json = String(data: data, encoding: .utf8)
            {
                parameters = json
            } else {
                parameters = ""
            }
        }
    }

    // MARK: - Cached Action

    public struct CachedAction: Codable, Sendable {
        let result: ActionResult
        let timestamp: Date
        let ttl: TimeInterval
        let metadata: CacheMetadata

        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }

    public struct CacheMetadata: Codable, Sendable {
        let cacheTime: TimeInterval
        let compressionRatio: Double?
        let tier: CacheTier
        let accessCount: Int
        let lastAccessed: Date
    }

    public enum CacheTier: String, Codable, Sendable {
        case l1 = "L1"
        case l2 = "L2"
        case l3 = "L3"
    }

    // MARK: - Initialization

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        l1Cache = LRUCache(maxSize: configuration.l1MaxSize)
        l2Cache = CompressedCache(maxSize: configuration.l2MaxSize)

        // Create offline cache configuration for DiskCache
        let cacheConfig = OfflineCacheConfiguration(
            maxSize: Int64(configuration.l3MaxSizeMB * 1024 * 1024),
            defaultExpiration: configuration.defaultTTL,
            useEncryption: false,
            evictionPolicy: .leastRecentlyUsed
        )

        do {
            l3Cache = try DiskCache(configuration: cacheConfig) as any OfflineCacheProtocol
        } catch {
            // Fallback to memory cache if disk cache fails
            l3Cache = MemoryCache(configuration: cacheConfig) as any OfflineCacheProtocol
        }
    }

    // MARK: - Cache Operations

    /// Get cached action result with multi-tier lookup
    public func get(_ action: ObjectAction) async -> ActionResult? {
        let key = CacheKey(action: action)
        metrics.totalRequests += 1

        // L1 lookup
        if let cached = l1Cache.get(key), !cached.isExpired {
            metrics.l1Hits += 1
            await updateAccessMetadata(key: key, tier: .l1)
            return cached.result
        }
        metrics.l1Misses += 1

        // L2 lookup
        if let cached = await l2Cache.get(key), !cached.isExpired {
            metrics.l2Hits += 1

            // Promote to L1
            l1Cache.set(key, value: cached)
            await updateAccessMetadata(key: key, tier: .l2)

            return cached.result
        }
        metrics.l2Misses += 1

        // L3 lookup
        if let cached = try? await retrieveFromL3Cache(key: key.hashValue.description), !cached.isExpired {
            metrics.l3Hits += 1

            // Promote to L2 and L1
            await l2Cache.set(key, value: cached)
            l1Cache.set(key, value: cached)
            await updateAccessMetadata(key: key, tier: .l3)

            return cached.result
        }
        metrics.l3Misses += 1

        return nil
    }

    /// Set action result in appropriate cache tier
    public func set(_ action: ObjectAction, result: ActionResult, ttl: TimeInterval? = nil) async {
        let key = CacheKey(action: action)
        let effectiveTTL = ttl ?? determineTTL(for: action, result: result)

        let metadata = CacheMetadata(
            cacheTime: Date().timeIntervalSince1970,
            compressionRatio: nil,
            tier: .l1,
            accessCount: 0,
            lastAccessed: Date()
        )

        let cached = CachedAction(
            result: result,
            timestamp: Date(),
            ttl: effectiveTTL,
            metadata: metadata
        )

        // Determine initial tier based on action priority and result size
        let tier = determineCacheTier(action: action, result: result)

        switch tier {
        case .l1:
            l1Cache.set(key, value: cached)
        case .l2:
            await l2Cache.set(key, value: cached)
        case .l3:
            try? await storeToL3Cache(cached, key: key.hashValue.description)
        }
    }

    /// Invalidate cache entries
    public func invalidate(matching predicate: @Sendable (CacheKey) -> Bool) async {
        // Track invalidation metrics
        let startTime = Date()
        var invalidatedCount = 0

        // Invalidate L1
        let l1Count = l1Cache.removeAll(where: predicate)
        invalidatedCount += l1Count

        // Invalidate L2
        let l2Count = await l2Cache.removeAll(where: predicate)
        invalidatedCount += l2Count

        // Invalidate L3 (more expensive operation)
        let l3Count = await invalidateL3(matching: predicate)
        invalidatedCount += l3Count

        // Update metrics
        let duration = Date().timeIntervalSince(startTime)
        await recordInvalidation(count: invalidatedCount, duration: duration)

        // Notify invalidation strategy
        await notifyInvalidation(predicate: predicate, count: invalidatedCount)
    }

    /// Clear all cache tiers
    public func clear() async {
        let startTime = Date()

        l1Cache.clear()
        await l2Cache.clear()
        try? await clearL3Cache()

        let duration = Date().timeIntervalSince(startTime)

        // Reset metrics but keep history
        let totalRequests = metrics.totalRequests
        metrics = CacheMetrics()
        metrics.totalClears += 1
        metrics.lastClearTime = Date()
        metrics.totalRequests = totalRequests

        // Log clear operation
        print("[Cache] Cleared all tiers in \(duration)s")
    }

    /// Get current cache metrics
    public func getMetrics() -> CacheMetrics {
        metrics
    }

    // MARK: - Cache Intelligence

    /// Determine appropriate TTL based on action characteristics
    private func determineTTL(for action: ObjectAction, result: ActionResult) -> TimeInterval {
        var ttl = configuration.defaultTTL

        // Adjust based on action type
        switch action.type {
        case .read:
            ttl *= 2.0 // Longer TTL for read operations
        case .analyze, .generate:
            ttl *= 0.5 // Shorter TTL for dynamic operations
        case .validate:
            ttl *= 1.5 // Medium TTL for validation
        default:
            break
        }

        // Adjust based on result status
        if result.status == .failed {
            ttl *= 0.25 // Much shorter TTL for failures
        }

        // Adjust based on object type
        switch action.objectType {
        case .document, .acquisition:
            ttl *= 0.75 // Shorter TTL for frequently changing objects
        case .documentTemplate:
            ttl *= 2.0 // Longer TTL for templates
        default:
            break
        }

        return ttl
    }

    /// Determine which cache tier to use based on action characteristics
    private func determineCacheTier(action: ObjectAction, result: ActionResult) -> CacheTier {
        // High priority actions go to L1
        if action.priority == .critical || action.priority == .high {
            return .l1
        }

        // Failed results go to L3
        if result.status == .failed {
            return .l3
        }

        // Large results go to L3
        if let output = result.output, output.data.count > 1024 * 100 { // 100KB
            return .l3
        }

        // Frequently accessed action types go to L1/L2
        switch action.type {
        case .read, .validate:
            return .l1
        case .analyze, .generate:
            return .l2
        default:
            return .l2
        }
    }

    /// Update access metadata for cache promotion
    private func updateAccessMetadata(key _: CacheKey, tier _: CacheTier) async {
        // Update access patterns for intelligent promotion/demotion
        // This would be used by a background process to optimize cache distribution
    }

    /// Invalidate L3 cache entries matching predicate
    private func invalidateL3(matching _: (CacheKey) -> Bool) async -> Int {
        // In a production system, this would use an index
        // For now, we'll skip implementation as it requires listing all L3 entries
        0
    }

    /// Record invalidation metrics
    private func recordInvalidation(count: Int, duration: TimeInterval) async {
        metrics.totalInvalidations += count
        metrics.invalidationDurations.append(duration)

        // Keep only last 100 durations
        if metrics.invalidationDurations.count > 100 {
            metrics.invalidationDurations.removeFirst(metrics.invalidationDurations.count - 100)
        }
    }

    /// Notify invalidation strategy of invalidation event
    private func notifyInvalidation(predicate _: (CacheKey) -> Bool, count: Int) async {
        // This would integrate with CacheInvalidationStrategy
        // For now, just log
        print("[Cache] Invalidated \(count) entries")
    }

    // MARK: - Cache Warming

    /// Warm cache with predicted actions
    public func warmCache(predictions: [ObjectAction]) async {
        guard configuration.warmupEnabled else { return }

        // Sort by priority and estimated benefit
        let sorted = predictions.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.estimatedDuration > rhs.estimatedDuration
        }

        // Warm cache with top predictions
        for action in sorted.prefix(50) {
            // Check if already cached
            let key = CacheKey(action: action)

            let l2Value = await l2Cache.get(key)
            if l1Cache.get(key) != nil || l2Value != nil {
                continue
            }

            // This would trigger pre-computation in a real system
            // For now, we'll just mark it for warming
        }
    }
    
    // MARK: - Actor-Isolated Cache Helpers
    
    /// Actor-isolated helper for L3 cache retrieval
    private func retrieveFromL3Cache(key: String) async throws -> CachedAction? {
        return try await l3Cache.retrieve(CachedAction.self, forKey: key)
    }
    
    /// Actor-isolated helper for L3 cache storage
    private func storeToL3Cache(_ cached: CachedAction, key: String) async throws {
        try await l3Cache.store(cached, forKey: key)
    }
    
    /// Actor-isolated helper for L3 cache clearing
    private func clearL3Cache() async throws {
        try await l3Cache.clearAll()
    }
}

// MARK: - LRU Cache Implementation

private class LRUCache<Key: Hashable, Value> {
    private var cache: [Key: Node] = [:]
    private var head: Node?
    private var tail: Node?
    private let maxSize: Int
    private let lock = NSLock()

    private class Node {
        var key: Key
        var value: Value
        var prev: Node?
        var next: Node?

        init(key: Key, value: Value) {
            self.key = key
            self.value = value
        }
    }

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    func get(_ key: Key) -> Value? {
        lock.lock()
        defer { lock.unlock() }

        guard let node = cache[key] else { return nil }

        // Move to head
        moveToHead(node)

        return node.value
    }

    func set(_ key: Key, value: Value) {
        lock.lock()
        defer { lock.unlock() }

        if let node = cache[key] {
            // Update value and move to head
            node.value = value
            moveToHead(node)
        } else {
            // Create new node
            let node = Node(key: key, value: value)
            cache[key] = node
            addToHead(node)

            // Evict if necessary
            if cache.count > maxSize {
                evictLRU()
            }
        }
    }

    func removeAll(where predicate: (Key) -> Bool) -> Int {
        lock.lock()
        defer { lock.unlock() }

        let keysToRemove = cache.keys.filter(predicate)
        for key in keysToRemove {
            if let node = cache[key] {
                removeNode(node)
                cache.removeValue(forKey: key)
            }
        }
        return keysToRemove.count
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll()
        head = nil
        tail = nil
    }

    private func moveToHead(_ node: Node) {
        removeNode(node)
        addToHead(node)
    }

    private func addToHead(_ node: Node) {
        node.next = head
        node.prev = nil

        if let head {
            head.prev = node
        }

        head = node

        if tail == nil {
            tail = node
        }
    }

    private func removeNode(_ node: Node) {
        let prev = node.prev
        let next = node.next

        if let prev {
            prev.next = next
        } else {
            head = next
        }

        if let next {
            next.prev = prev
        } else {
            tail = prev
        }
    }

    private func evictLRU() {
        guard let tail else { return }

        removeNode(tail)
        cache.removeValue(forKey: tail.key)
    }
}

// MARK: - Compressed Cache Implementation

private actor CompressedCache<Key: Hashable, Value: Codable> {
    private var cache: [Key: Data] = [:]
    private let maxSize: Int
    private let compression: NSData.CompressionAlgorithm = .lz4

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    func get(_ key: Key) async -> Value? {
        guard let compressedData = cache[key] else { return nil }

        // Decompress and decode
        guard let decompressed = try? (compressedData as NSData).decompressed(using: compression),
              let value = try? JSONDecoder().decode(Value.self, from: decompressed as Data)
        else {
            return nil
        }

        return value
    }

    func set(_ key: Key, value: Value) async {
        // Encode and compress
        guard let data = try? JSONEncoder().encode(value),
              let compressed = try? (data as NSData).compressed(using: compression)
        else {
            return
        }

        cache[key] = compressed as Data

        // Evict if necessary
        if cache.count > maxSize {
            // Remove random entry (simple eviction for now)
            if let firstKey = cache.keys.first {
                cache.removeValue(forKey: firstKey)
            }
        }
    }

    func removeAll(where predicate: (Key) -> Bool) async -> Int {
        let keysToRemove = cache.keys.filter(predicate)
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
        return keysToRemove.count
    }

    func clear() async {
        cache.removeAll()
    }
}

// MARK: - ActionContext Cache Key Extension

extension ActionContext {
    var cacheKey: String {
        // Create a stable cache key from context
        var components: [String] = []

        components.append(userId)
        components.append(sessionId)
        components.append(environment.rawValue)
        components.append(metadata.sorted(by: { $0.key < $1.key }).map { "\($0.key):\($0.value)" }.joined(separator: ","))

        return components.joined(separator: "|").data(using: .utf8)?.base64EncodedString() ?? ""
    }
}

// MARK: - Dependency Registration

extension ObjectActionCache: DependencyKey {
    public static let liveValue = ObjectActionCache()
}

public extension DependencyValues {
    var objectActionCache: ObjectActionCache {
        get { self[ObjectActionCache.self] }
        set { self[ObjectActionCache.self] = newValue }
    }
}
