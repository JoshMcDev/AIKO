import AppCore
import ComposableArchitecture
import Foundation

/// Demo showcasing distributed cache functionality
@MainActor
public func demonstrateDistributedCache() async throws {
    print("🌐 Distributed Cache Demo")
    print("========================\n")

    // 1. Create distributed cache with configuration
    print("1️⃣ Creating distributed cache cluster...")

    let config = DistributedCacheConfiguration(
        nodeId: "node-001",
        clusterEndpoints: ["localhost:7001", "localhost:7002"],
        replicationFactor: 3,
        consistencyLevel: .quorum,
        partitionStrategy: .consistentHashing,
        syncInterval: 5.0,
        heartbeatInterval: 1.0,
        failoverTimeout: 10.0
    )

    let distributedCache = DistributedCache(configuration: config)

    // Subscribe to events
    let cancellable = distributedCache.subscribe().sink { event in
        print("📡 Event: \(event)")
    }

    // Give it time to initialize
    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

    // 2. Demonstrate consistent hashing
    print("\n2️⃣ Demonstrating consistent hashing...")
    await demonstrateConsistentHashing()

    // 3. Demonstrate cache operations
    print("\n3️⃣ Performing distributed cache operations...")

    // Set operation with quorum consistency
    struct UserProfile: Codable {
        let id: String
        let name: String
        let preferences: [String: String]
    }

    let profile = UserProfile(
        id: "user-123",
        name: "Alice Smith",
        preferences: ["theme": "dark", "language": "en"]
    )

    let key = "profile:user-123"
    print("   Setting \(key) with quorum consistency...")
    try await distributedCache.set(key, value: profile, ttl: 3600)

    // Get operation
    print("   Getting \(key)...")
    if let retrieved: UserProfile = try await distributedCache.get(key) {
        print("   ✅ Retrieved: \(retrieved.name)")
    }

    // 4. Demonstrate batch operations
    print("\n4️⃣ Performing batch operations...")

    let profiles = [
        "profile:user-456": UserProfile(id: "user-456", name: "Bob Jones", preferences: [:]),
        "profile:user-789": UserProfile(id: "user-789", name: "Charlie Brown", preferences: [:]),
    ]

    print("   Setting multiple profiles...")
    try await distributedCache.setMultiple(profiles, ttl: 3600)

    print("   Getting multiple profiles...")
    let keys = Array(profiles.keys)
    let retrieved = try await distributedCache.getMultiple(keys, type: UserProfile.self)
    print("   ✅ Retrieved \(retrieved.count) profiles")

    // 5. Demonstrate statistics
    print("\n5️⃣ Cache statistics...")
    let stats = try await distributedCache.getStats()
    print("   Total Nodes: \(stats.totalNodes)")
    print("   Active Nodes: \(stats.activeNodes)")
    print("   Total Keys: \(stats.totalKeys)")
    print("   Hit Rate: \(String(format: "%.2f%%", stats.hitRate * 100))")
    print("   Avg Latency: \(String(format: "%.2fms", stats.averageLatency * 1000))")
    print("   Replication Factor: \(stats.replicationFactor)")

    // 6. Demonstrate failover (simulated)
    print("\n6️⃣ Simulating node failure and failover...")
    print("   Node-002 going down...")
    // In a real scenario, this would trigger automatic failover

    // 7. Demonstrate rebalancing
    print("\n7️⃣ Demonstrating cache rebalancing...")
    print("   Adding new node to cluster...")
    // This would trigger automatic rebalancing

    // Clean up
    cancellable.cancel()

    print("\n✅ Distributed cache demo complete!")
}

/// Demonstrate consistent hashing algorithm
private func demonstrateConsistentHashing() async {
    let hash = ConsistentHash(virtualNodes: 150)

    // Add nodes
    let nodes = ["node-001", "node-002", "node-003", "node-004"]
    for node in nodes {
        await hash.addNode(node)
    }

    // Show key distribution
    print("   Key distribution across nodes:")
    for i in 0 ..< 10 {
        let key = "test-key-\(i)"
        let node = await hash.getNode(for: key)
        let replicas = await hash.getReplicaNodes(for: key, count: 2)
        print("   \(key) -> Primary: \(node ?? "None"), Replicas: \(replicas)")
    }

    // Show load distribution
    let distribution = await hash.getLoadDistribution()
    print("\n   Load distribution (10,000 keys):")
    for (node, percentage) in distribution.sorted(by: { $0.key < $1.key }) {
        let bar = String(repeating: "█", count: Int(percentage / 2))
        print("   \(node): \(bar) \(String(format: "%.1f%%", percentage))")
    }

    // Demonstrate node removal and key migration
    print("\n   Removing node-002...")
    await hash.removeNode("node-002")

    print("   Keys that would migrate:")
    let testKeys = Set((0 ..< 20).map { "test-key-\($0)" })
    let affected = await hash.getAffectedKeys(for: "node-002", from: testKeys)
    print("   \(affected.count) keys would be redistributed")
}

// MARK: - Demo Runner

/// Main entry point for the demo
public enum DistributedCacheDemoRunner {
    public static func main() async {
        do {
            try await demonstrateDistributedCache()
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
