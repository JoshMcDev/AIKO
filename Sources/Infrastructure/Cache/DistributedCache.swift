@preconcurrency import Combine
import ComposableArchitecture
import Foundation

/// Distributed cache implementation with consistent hashing
public actor DistributedCache: DistributedCacheProtocol {
    // MARK: - Properties

    private let configuration: DistributedCacheConfiguration
    private let localCache: ObjectActionCache
    private var consistentHash: ConsistentHash
    private var nodes: [String: NodeInfo] = [:]
    private let eventSubject = PassthroughSubject<DistributedCacheEvent, Never>()
    private nonisolated let eventPublisher: AnyPublisher<DistributedCacheEvent, Never>

    // Networking
    private var connections: [String: CacheConnection] = [:]
    private var heartbeatTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?

    // Metrics
    private var metrics = DistributedCacheMetrics()

    // MARK: - Node Information

    private struct NodeInfo {
        let id: String
        let endpoint: String
        var lastHeartbeat: Date
        var isActive: Bool
        var load: Double
        var keyCount: Int
    }

    // MARK: - Initialization

    public init(configuration: DistributedCacheConfiguration = .init()) {
        self.configuration = configuration
        localCache = ObjectActionCache()
        consistentHash = ConsistentHash(virtualNodes: 150)
        eventPublisher = eventSubject.eraseToAnyPublisher()

        // Initialize local node
        let localNode = NodeInfo(
            id: configuration.nodeId,
            endpoint: "local",
            lastHeartbeat: Date(),
            isActive: true,
            load: 0.0,
            keyCount: 0
        )
        nodes[configuration.nodeId] = localNode

        // Start background tasks
        Task {
            await consistentHash.addNode(configuration.nodeId)
            await startHeartbeat()
            await startSync()
            await joinCluster()
        }
    }

    deinit {
        heartbeatTask?.cancel()
        syncTask?.cancel()
    }

    // MARK: - DistributedCacheProtocol Implementation

    public func get<T: Codable & Sendable>(_ key: String) async throws -> T? {
        let startTime = Date()

        // Determine which node owns this key
        let nodeId = await consistentHash.getNode(for: key)

        if let nodeId = nodeId, nodeId == configuration.nodeId {
            // Local lookup
            if let cachedAction = await getCachedAction(for: key) {
                let data = try JSONEncoder().encode(cachedAction)
                let result = try JSONDecoder().decode(T.self, from: data)

                await recordMetrics(operation: DistributedCacheMetrics.MetricOperation.get, duration: Date().timeIntervalSince(startTime), hit: true)
                return result
            }
        } else if let nodeId = nodeId {
            // Remote lookup
            if let connection = getConnection(nodeId) {
                if let data = try await connection.get(key: key) {
                    let result = try JSONDecoder().decode(T.self, from: data)

                    // Optionally cache locally for read-through
                    if configuration.consistencyLevel == .eventual {
                        try? await set(key, value: result, ttl: 300) // 5 min local cache
                    }

                    await recordMetrics(operation: DistributedCacheMetrics.MetricOperation.get, duration: Date().timeIntervalSince(startTime), hit: true)
                    return result
                }
            }
        }

        await recordMetrics(operation: DistributedCacheMetrics.MetricOperation.get, duration: Date().timeIntervalSince(startTime), hit: false)
        return nil
    }

    public func set(_ key: String, value: some Codable & Sendable, ttl: TimeInterval? = nil) async throws {
        let startTime = Date()
        let data = try JSONEncoder().encode(value)

        // Determine primary node
        let primaryNode = await consistentHash.getNode(for: key)

        // Get replica nodes - simplified for now
        let replicaNodes: [String] = []

        // Write to primary
        if let primaryNode = primaryNode, primaryNode == configuration.nodeId {
            // Local write
            await setCachedAction(key: key, data: data, ttl: ttl)
        } else if let primaryNode = primaryNode {
            // Remote write
            if let connection = connections[primaryNode] {
                try await connection.set(key: key, data: data, ttl: ttl)
            }
        }

        // Replicate based on consistency level
        switch configuration.consistencyLevel {
        case .strong:
            // Wait for all replicas
            try await replicateToAll(key: key, data: data, ttl: ttl, nodes: replicaNodes)

        case .quorum:
            // Wait for majority
            let quorumSize = (configuration.replicationFactor / 2) + 1
            try await replicateToQuorum(key: key, data: data, ttl: ttl, nodes: replicaNodes, quorum: quorumSize)

        case .eventual:
            // Fire and forget
            Task {
                try? await replicateToAll(key: key, data: data, ttl: ttl, nodes: replicaNodes)
            }
        }

        await recordMetrics(operation: DistributedCacheMetrics.MetricOperation.set, duration: Date().timeIntervalSince(startTime))

        // Emit replication event
        let allNodes = (primaryNode.map { [$0] } ?? []) + replicaNodes
        eventSubject.send(.replicationComplete(key: key, nodes: allNodes))
    }

    public func remove(_ key: String) async throws {
        let primaryNode = await consistentHash.getNode(for: key)
        let replicaNodes: [String] = [] // Simplified for now

        // Remove from all nodes
        let allNodes = (primaryNode.map { [$0] } ?? []) + replicaNodes

        let localNodeId = configuration.nodeId
        await withTaskGroup(of: Void.self) { group in
            for nodeId in allNodes {
                group.addTask { [weak self] in
                    guard let self else { return }
                    if nodeId == localNodeId {
                        await removeCachedAction(key: key)
                    } else if let connection = await getConnection(nodeId) {
                        try? await connection.remove(key: key)
                    }
                }
            }
        }

        eventSubject.send(.keyInvalidated(key: key, nodeId: configuration.nodeId))
    }

    public func exists(_ key: String) async throws -> Bool {
        try await get(key) as Data? != nil
    }

    public func getMultiple<T: Codable & Sendable>(_ keys: [String], type _: T.Type) async throws -> [String: T] {
        var results: [String: T] = [:]

        // Group keys by node
        let keysByNode = await groupKeysByNode(keys)

        // Fetch from each node in parallel
        await withTaskGroup(of: (String, T?).self) { group in
            for (nodeId, nodeKeys) in keysByNode {
                for key in nodeKeys {
                    group.addTask {
                        let value: T? = try? await self.getSingleFromNode(key: key, nodeId: nodeId)
                        return (key, value)
                    }
                }
            }

            for await (key, value) in group {
                if let value {
                    results[key] = value
                }
            }
        }

        return results
    }

    public func setMultiple<T: Codable & Sendable>(_ values: [String: T], ttl: TimeInterval? = nil) async throws {
        // Group by primary node
        var valuesByNode: [String: [String: T]] = [:]

        for (key, value) in values {
            if let nodeId = await consistentHash.getNode(for: key) {
                valuesByNode[nodeId, default: [:]][key] = value
            }
        }

        // Set on each node in parallel
        let localNodeId = configuration.nodeId
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (nodeId, nodeValues) in valuesByNode {
                group.addTask { [weak self] in
                    guard let self else { return }
                    if nodeId == localNodeId {
                        for (key, value) in nodeValues {
                            try await set(key, value: value, ttl: ttl)
                        }
                    } else if let connection = await getConnection(nodeId) {
                        try await connection.setMultiple(nodeValues, ttl: ttl)
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    public func removeMultiple(_ keys: [String]) async throws {
        await withTaskGroup(of: Void.self) { group in
            for key in keys {
                group.addTask {
                    try? await self.remove(key)
                }
            }
        }
    }

    public func getStats() async throws -> DistributedCacheStats {
        let activeNodes = nodes.values.filter(\.isActive).count
        let totalKeys = nodes.values.reduce(0) { $0 + $1.keyCount }

        return await DistributedCacheStats(
            totalNodes: nodes.count,
            activeNodes: activeNodes,
            totalKeys: totalKeys,
            memoryUsage: calculateMemoryUsage(),
            hitRate: metrics.hitRate,
            averageLatency: metrics.averageLatency,
            replicationFactor: configuration.replicationFactor
        )
    }

    public nonisolated func subscribe() -> AnyPublisher<DistributedCacheEvent, Never> {
        eventPublisher
    }

    // MARK: - Cluster Management

    private func joinCluster() async {
        for endpoint in configuration.clusterEndpoints {
            do {
                let connection = try await CacheConnection.connect(to: endpoint)

                // Exchange node information
                let nodeInfo = try await connection.exchangeNodeInfo(
                    nodeId: configuration.nodeId,
                    endpoint: "local"
                )

                // Add discovered nodes
                for (nodeId, info) in nodeInfo where nodeId != configuration.nodeId {
                    nodes[nodeId] = NodeInfo(
                        id: nodeId,
                        endpoint: info.endpoint,
                        lastHeartbeat: Date(),
                        isActive: true,
                        load: info.load,
                        keyCount: info.keyCount
                    )
                    await consistentHash.addNode(nodeId)
                    connections[nodeId] = try await CacheConnection.connect(to: info.endpoint)

                    eventSubject.send(.nodeJoined(nodeId: nodeId))
                }

                break // Successfully joined
            } catch {
                print("[DistributedCache] Failed to connect to \(endpoint): \(error)")
            }
        }
    }

    private func startHeartbeat() async {
        heartbeatTask = Task {
            while !Task.isCancelled {
                await sendHeartbeats()
                await checkNodeHealth()

                try? await Task.sleep(nanoseconds: UInt64(configuration.heartbeatInterval * 1_000_000_000))
            }
        }
    }

    private func startSync() async {
        syncTask = Task {
            while !Task.isCancelled {
                await syncWithPeers()

                try? await Task.sleep(nanoseconds: UInt64(configuration.syncInterval * 1_000_000_000))
            }
        }
    }

    private func sendHeartbeats() async {
        let localMetrics = await localCache.getMetrics()

        await withTaskGroup(of: Void.self) { group in
            for (nodeId, connection) in connections {
                group.addTask {
                    do {
                        try await connection.sendHeartbeat(
                            from: self.configuration.nodeId,
                            keyCount: localMetrics.totalRequests,
                            load: self.calculateLoad()
                        )
                    } catch {
                        print("[DistributedCache] Failed to send heartbeat to \(nodeId): \(error)")
                    }
                }
            }
        }
    }

    private func checkNodeHealth() async {
        let now = Date()
        let timeout = configuration.failoverTimeout

        for (nodeId, nodeInfo) in nodes where nodeId != configuration.nodeId {
            if now.timeIntervalSince(nodeInfo.lastHeartbeat) > timeout {
                // Node is down, initiate failover
                await handleNodeFailure(nodeId: nodeId)
            }
        }
    }

    private func handleNodeFailure(nodeId: String) async {
        guard var nodeInfo = nodes[nodeId], nodeInfo.isActive else { return }

        // Mark node as inactive
        nodeInfo.isActive = false
        nodes[nodeId] = nodeInfo

        // Remove from consistent hash
        await consistentHash.removeNode(nodeId)

        // Close connection
        await connections[nodeId]?.close()
        connections.removeValue(forKey: nodeId)

        eventSubject.send(.nodeLeft(nodeId: nodeId))

        // Initiate rebalancing
        await rebalanceKeys()
    }

    private func rebalanceKeys() async {
        eventSubject.send(.rebalancing(progress: 0.0))

        // This would involve:
        // 1. Identifying keys that need to be moved
        // 2. Transferring them to new nodes
        // 3. Updating replicas

        // Simplified version for demo
        let progress = 1.0
        eventSubject.send(.rebalancing(progress: progress))
    }

    private func syncWithPeers() async {
        // Get local cache metrics and keys
        _ = await localCache.getMetrics()

        // Check each key assignment
        let keysToTransfer = await identifyMisplacedKeys()

        if !keysToTransfer.isEmpty {
            eventSubject.send(.rebalancing(progress: 0.0))

            var transferred = 0
            let total = keysToTransfer.count

            for (key, targetNodeId) in keysToTransfer {
                if let connection = connections[targetNodeId] {
                    do {
                        // Get the cached action data
                        if let cachedAction = await getCachedAction(for: key) {
                            let data = try JSONEncoder().encode(cachedAction)

                            // Transfer to correct node
                            try await connection.set(key: key, data: data, ttl: nil)

                            // Remove from local
                            await removeCachedAction(key: key)

                            transferred += 1
                            let progress = Double(transferred) / Double(total)
                            eventSubject.send(.rebalancing(progress: progress))
                        }
                    } catch {
                        print("[DistributedCache] Failed to transfer key \(key): \(error)")
                    }
                }
            }

            eventSubject.send(.rebalancing(progress: 1.0))
        }

        // Verify replicas
        await verifyReplicas()
    }

    private func identifyMisplacedKeys() async -> [(String, String)] {
        let misplacedKeys: [(String, String)] = []

        // In a real implementation, you would iterate through all local keys
        // For now, we'll simulate this
        // This would need access to all keys in the local cache

        return misplacedKeys
    }

    private func verifyReplicas() async {
        // Verify that all keys have the correct number of replicas
        // This would involve checking each key's replica count
        // and creating missing replicas if needed
    }

    // MARK: - Helper Methods

    private func getConnection(_ nodeId: String) -> CacheConnection? {
        connections[nodeId]
    }

    private func getCachedAction(for _: String) async -> ObjectActionCache.CachedAction? {
        // Convert key to ObjectAction for cache lookup
        // This is simplified - in reality you'd parse the key
        nil // Placeholder
    }

    private func setCachedAction(key _: String, data _: Data, ttl _: TimeInterval?) async {
        // Store in local cache
        // This is simplified - in reality you'd convert to ObjectAction
    }

    private func removeCachedAction(key _: String) async {
        // Remove from local cache
    }

    private func getSingleFromNode<T: Codable & Sendable>(key: String, nodeId: String) async throws -> T? {
        if nodeId == configuration.nodeId {
            return try await get(key)
        } else if let connection = getConnection(nodeId) {
            if let data = try await connection.get(key: key) {
                return try JSONDecoder().decode(T.self, from: data)
            }
        }
        return nil
    }

    private func groupKeysByNode(_ keys: [String]) async -> [String: [String]] {
        var keysByNode: [String: [String]] = [:]

        for key in keys {
            if let nodeId = await consistentHash.getNode(for: key) {
                keysByNode[nodeId, default: []].append(key)
            }
        }

        return keysByNode
    }

    private func replicateToAll(key: String, data: Data, ttl: TimeInterval?, nodes: [String]) async throws {
        let localNodeId = configuration.nodeId
        try await withThrowingTaskGroup(of: Void.self) { group in
            for nodeId in nodes {
                group.addTask { [weak self] in
                    guard let self else { return }
                    if nodeId == localNodeId {
                        await setCachedAction(key: key, data: data, ttl: ttl)
                    } else if let connection = await getConnection(nodeId) {
                        try await connection.set(key: key, data: data, ttl: ttl)
                    }
                }
            }

            try await group.waitForAll()
        }
    }

    private func replicateToQuorum(key: String, data: Data, ttl: TimeInterval?, nodes: [String], quorum: Int) async throws {
        var successCount = 1 // Primary already written
        let localNodeId = configuration.nodeId

        await withTaskGroup(of: Bool.self) { group in
            for nodeId in nodes {
                group.addTask { [weak self] in
                    guard let self else { return false }
                    if nodeId == localNodeId {
                        await setCachedAction(key: key, data: data, ttl: ttl)
                        return true
                    } else if let connection = await getConnection(nodeId) {
                        do {
                            try await connection.set(key: key, data: data, ttl: ttl)
                            return true
                        } catch {
                            return false
                        }
                    }
                    return false
                }
            }

            for await success in group where success {
                successCount += 1
                if successCount >= quorum {
                    group.cancelAll()
                    break
                }
            }
        }

        if successCount < quorum {
            throw DistributedCacheError.quorumNotMet
        }
    }

    private func calculateLoad() async -> Double {
        let metrics = await localCache.getMetrics()
        let totalRequests = Double(metrics.totalRequests)
        let maxRequests = 10000.0 // Configurable

        return min(totalRequests / maxRequests, 1.0)
    }

    private func calculateMemoryUsage() async -> Int64 {
        // Simplified - would calculate actual memory usage
        let metrics = await localCache.getMetrics()
        return Int64(metrics.totalRequests * 1024) // Rough estimate
    }

    private func recordMetrics(operation: DistributedCacheMetrics.MetricOperation, duration: TimeInterval, hit: Bool = false) async {
        metrics.record(operation: operation, duration: duration, hit: hit)
    }
}

// MARK: - Supporting Types

private struct DistributedCacheMetrics {
    private var totalRequests: Int = 0
    private var cacheHits: Int = 0
    private var totalLatency: TimeInterval = 0

    enum MetricOperation {
        case get, set, remove
    }

    var hitRate: Double {
        totalRequests > 0 ? Double(cacheHits) / Double(totalRequests): 0
    }

    var averageLatency: TimeInterval {
        totalRequests > 0 ? totalLatency / Double(totalRequests): 0
    }

    mutating func record(operation: MetricOperation, duration: TimeInterval, hit: Bool = false) {
        totalRequests += 1
        totalLatency += duration

        if operation == .get, hit {
            cacheHits += 1
        }
    }
}

enum DistributedCacheError: Error {
    case quorumNotMet
    case nodeNotFound
    case connectionFailed
    case replicationFailed
}

// MARK: - Dependency Registration

extension DistributedCache: DependencyKey {
    public static let liveValue = DistributedCache()
}

public extension DependencyValues {
    var distributedCache: DistributedCache {
        get { self[DistributedCache.self] }
        set { self[DistributedCache.self] = newValue }
    }
}
