import Foundation
import CommonCrypto

/// Consistent hashing implementation for distributed cache node selection
public actor ConsistentHash {
    // MARK: - Properties
    
    private var ring: [UInt32: String] = [:]
    private var sortedHashes: [UInt32] = []
    private let virtualNodes: Int
    private let lock = NSLock()
    
    // MARK: - Initialization
    
    public init(virtualNodes: Int = 150) {
        self.virtualNodes = virtualNodes
    }
    
    // MARK: - Public Methods
    
    /// Add a node to the consistent hash ring
    public func addNode(_ nodeId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        // Add virtual nodes for better distribution
        for i in 0..<virtualNodes {
            let virtualNodeId = "\(nodeId):\(i)"
            let hash = calculateHash(virtualNodeId)
            ring[hash] = nodeId
        }
        
        updateSortedHashes()
    }
    
    /// Remove a node from the consistent hash ring
    public func removeNode(_ nodeId: String) {
        lock.lock()
        defer { lock.unlock() }
        
        // Remove all virtual nodes for this node
        for i in 0..<virtualNodes {
            let virtualNodeId = "\(nodeId):\(i)"
            let hash = calculateHash(virtualNodeId)
            ring.removeValue(forKey: hash)
        }
        
        updateSortedHashes()
    }
    
    /// Get the node responsible for a given key
    public func getNode(for key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        guard !sortedHashes.isEmpty else { return nil }
        
        let keyHash = calculateHash(key)
        
        // Find the first node with hash >= keyHash
        for hash in sortedHashes {
            if hash >= keyHash {
                return ring[hash]
            }
        }
        
        // Wrap around to the first node
        return ring[sortedHashes.first!]
    }
    
    /// Get multiple nodes for replication
    public func getNodes(for key: String, count: Int) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        guard !sortedHashes.isEmpty else { return [] }
        
        let keyHash = calculateHash(key)
        var result: [String] = []
        var uniqueNodes = Set<String>()
        
        // Find starting position
        var startIndex = 0
        for (index, hash) in sortedHashes.enumerated() {
            if hash >= keyHash {
                startIndex = index
                break
            }
        }
        
        // Collect unique nodes starting from the calculated position
        var currentIndex = startIndex
        while uniqueNodes.count < count && uniqueNodes.count < Set(ring.values).count {
            let hash = sortedHashes[currentIndex]
            if let nodeId = ring[hash] {
                if uniqueNodes.insert(nodeId).inserted {
                    result.append(nodeId)
                }
            }
            
            currentIndex = (currentIndex + 1) % sortedHashes.count
            
            // Prevent infinite loop if we've checked all positions
            if currentIndex == startIndex && uniqueNodes.count < count {
                break
            }
        }
        
        return result
    }
    
    /// Get all nodes in the ring
    public func getAllNodes() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(Set(ring.values))
    }
    
    /// Get the load distribution across nodes
    public func getLoadDistribution() -> [String: Int] {
        lock.lock()
        defer { lock.unlock() }
        
        var distribution: [String: Int] = [:]
        
        for nodeId in ring.values {
            distribution[nodeId, default: 0] += 1
        }
        
        return distribution
    }
    
    /// Get replica nodes for a key (excluding primary)
    public func getReplicaNodes(for key: String, count: Int) -> [String] {
        let allNodes = getNodes(for: key, count: count + 1) // +1 to include primary
        return Array(allNodes.dropFirst()) // Remove primary, return only replicas
    }
    
    /// Get keys that would be affected by node removal (for migration planning)
    public func getAffectedKeys(for nodeId: String, from keySet: Set<String>) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        
        var affectedKeys: [String] = []
        
        for key in keySet {
            if let currentNode = getNode(for: key), currentNode == nodeId {
                affectedKeys.append(key)
            }
        }
        
        return affectedKeys
    }
    
    // MARK: - Private Methods
    
    private func updateSortedHashes() {
        sortedHashes = Array(ring.keys).sorted()
    }
    
    private func calculateHash(_ input: String) -> UInt32 {
        // Use SHA-1 hash for consistent distribution
        let data = input.data(using: .utf8) ?? Data()
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        
        _ = data.withUnsafeBytes { bytes in
            CC_SHA1(bytes.bindMemory(to: UInt8.self).baseAddress, CC_LONG(data.count), &digest)
        }
        
        // Use first 4 bytes as UInt32
        return digest.withUnsafeBytes { bytes in
            bytes.load(as: UInt32.self)
        }
    }
}

// MARK: - Hash Ring Statistics

public extension ConsistentHash {
    struct RingStatistics {
        public let totalNodes: Int
        public let totalVirtualNodes: Int
        public let loadBalance: Double // Standard deviation of load distribution
        public let distribution: [String: Int]
        
        init(totalNodes: Int, totalVirtualNodes: Int, loadBalance: Double, distribution: [String: Int]) {
            self.totalNodes = totalNodes
            self.totalVirtualNodes = totalVirtualNodes
            self.loadBalance = loadBalance
            self.distribution = distribution
        }
    }
    
    func getStatistics() -> RingStatistics {
        lock.lock()
        defer { lock.unlock() }
        
        let distribution = getLoadDistribution()
        let totalNodes = distribution.count
        let totalVirtualNodes = ring.count
        
        // Calculate load balance (lower is better)
        let values = Array(distribution.values).map { Double($0) }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let standardDeviation = sqrt(variance)
        
        return RingStatistics(
            totalNodes: totalNodes,
            totalVirtualNodes: totalVirtualNodes,
            loadBalance: standardDeviation,
            distribution: distribution
        )
    }
}