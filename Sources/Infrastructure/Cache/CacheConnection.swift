import Foundation
import Network

/// Connection handler for distributed cache nodes
public actor CacheConnection {
    // MARK: - Properties

    private let endpoint: String
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.aiko.cache.connection")
    private var responseHandlers: [UUID: (Result<Data, Error>) -> Void] = [:]
    private var isConnected = false

    // MARK: - Connection Info

    public struct NodeInfo: Sendable {
        public let nodeId: String
        public let endpoint: String
        public let load: Double
        public let keyCount: Int
    }

    // MARK: - Messages

    private enum MessageType: UInt8 {
        case get = 1
        case set = 2
        case remove = 3
        case heartbeat = 4
        case nodeInfo = 5
        case response = 6
        case error = 7
    }

    private struct Message: Codable {
        let id: UUID
        let type: UInt8
        let payload: Data
    }

    // Move struct outside generic function
    private struct SetMultiplePayloadData: Codable {
        let values: [String: Data]
        let ttl: TimeInterval?
    }

    // MARK: - Initialization

    private init(endpoint: String) {
        self.endpoint = endpoint
    }

    // MARK: - Public Methods

    /// Connect to a cache node
    public static func connect(to endpoint: String) async throws -> CacheConnection {
        let connection = CacheConnection(endpoint: endpoint)
        try await connection.establishConnection()
        return connection
    }

    /// Get value from remote node
    public func get(key: String) async throws -> Data? {
        guard let payload = key.data(using: .utf8) else {
            throw CacheConnectionError.invalidKey
        }
        let response = try await sendRequest(type: .get, payload: payload)

        // Empty response means key not found
        return response.isEmpty ? nil : response
    }

    /// Set value on remote node
    public func set(key: String, data: Data, ttl: TimeInterval?) async throws {
        struct SetPayload: Codable {
            let key: String
            let data: Data
            let ttl: TimeInterval?
        }

        let payload = SetPayload(key: key, data: data, ttl: ttl)
        let encodedPayload = try JSONEncoder().encode(payload)

        _ = try await sendRequest(type: .set, payload: encodedPayload)
    }

    /// Remove value from remote node
    public func remove(key: String) async throws {
        guard let payload = key.data(using: .utf8) else {
            throw CacheConnectionError.invalidKey
        }
        _ = try await sendRequest(type: .remove, payload: payload)
    }

    /// Set multiple values
    public func setMultiple(_ values: [String: some Codable], ttl: TimeInterval?) async throws {
        // Convert to data dictionary
        var dataValues: [String: Data] = [:]
        for (key, value) in values {
            dataValues[key] = try JSONEncoder().encode(value)
        }

        let payload = SetMultiplePayloadData(values: dataValues, ttl: ttl)
        let encodedPayload = try JSONEncoder().encode(payload)

        _ = try await sendRequest(type: .set, payload: encodedPayload)
    }

    /// Send heartbeat
    public func sendHeartbeat(from nodeId: String, keyCount: Int, load: Double) async throws {
        struct HeartbeatPayload: Codable {
            let nodeId: String
            let keyCount: Int
            let load: Double
            let timestamp: Date
        }

        let payload = HeartbeatPayload(
            nodeId: nodeId,
            keyCount: keyCount,
            load: load,
            timestamp: Date()
        )

        let encodedPayload = try JSONEncoder().encode(payload)
        _ = try await sendRequest(type: .heartbeat, payload: encodedPayload)
    }

    /// Exchange node information
    public func exchangeNodeInfo(nodeId: String, endpoint: String) async throws -> [String: NodeInfo] {
        struct ExchangePayload: Codable {
            let nodeId: String
            let endpoint: String
        }

        let payload = ExchangePayload(nodeId: nodeId, endpoint: endpoint)
        let encodedPayload = try JSONEncoder().encode(payload)

        let response = try await sendRequest(type: .nodeInfo, payload: encodedPayload)

        struct NodeInfoResponse: Codable {
            let nodes: [String: NodeInfoData]

            struct NodeInfoData: Codable {
                let endpoint: String
                let load: Double
                let keyCount: Int
            }
        }

        let nodeInfoResponse = try JSONDecoder().decode(NodeInfoResponse.self, from: response)

        var result: [String: NodeInfo] = [:]
        for (nodeId, info) in nodeInfoResponse.nodes {
            result[nodeId] = NodeInfo(
                nodeId: nodeId,
                endpoint: info.endpoint,
                load: info.load,
                keyCount: info.keyCount
            )
        }

        return result
    }

    /// Close the connection
    public func close() {
        connection?.cancel()
        connection = nil
        isConnected = false

        // Fail all pending requests
        for (_, handler) in responseHandlers {
            handler(.failure(CacheConnectionError.connectionClosed))
        }
        responseHandlers.removeAll()
    }

    // MARK: - Private Methods

    private func establishConnection() async throws {
        // Parse endpoint
        let components = endpoint.split(separator: ":")
        guard components.count == 2,
              let port = NWEndpoint.Port(String(components[1]))
        else {
            throw CacheConnectionError.invalidEndpoint
        }

        let host = String(components[0])
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: port)

        // Create connection
        let parameters = NWParameters.tcp
        parameters.prohibitedInterfaceTypes = [.cellular]

        connection = NWConnection(to: endpoint, using: parameters)

        // Set up state handler
        await withCheckedContinuation { continuation in
            connection?.stateUpdateHandler = { [weak self] state in
                Task { [weak self] in
                    await self?.handleStateUpdate(state, continuation: continuation)
                }
            }

            // Start connection
            connection?.start(queue: queue)
        }

        // Start receiving
        Task {
            await startReceiving()
        }
    }

    private func handleStateUpdate(_ state: NWConnection.State, continuation: CheckedContinuation<Void, Never>?) {
        switch state {
        case .ready:
            isConnected = true
            continuation?.resume()

        case let .failed(error):
            isConnected = false
            print("[CacheConnection] Connection failed: \(error)")
            continuation?.resume()

        case .cancelled:
            isConnected = false
            continuation?.resume()

        default:
            break
        }
    }

    private func startReceiving() async {
        guard let connection else { return }

        while isConnected {
            do {
                // Read message length (4 bytes)
                let lengthData = try await readData(length: 4, from: connection)
                let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }

                // Read message
                let messageData = try await readData(length: Int(length), from: connection)
                let message = try JSONDecoder().decode(Message.self, from: messageData)

                // Handle message
                await handleMessage(message)
            } catch {
                print("[CacheConnection] Receive error: \(error)")
                break
            }
        }
    }

    private func readData(length: Int, from connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: length, maximumLength: length) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data, data.count == length {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: CacheConnectionError.incompleteData)
                }
            }
        }
    }

    private func handleMessage(_ message: Message) async {
        if message.type == MessageType.response.rawValue || message.type == MessageType.error.rawValue {
            // Response to our request
            if let handler = responseHandlers.removeValue(forKey: message.id) {
                if message.type == MessageType.response.rawValue {
                    handler(.success(message.payload))
                } else {
                    let error = String(data: message.payload, encoding: .utf8) ?? "Unknown error"
                    handler(.failure(CacheConnectionError.remoteError(error)))
                }
            }
        }
        // Handle other message types if needed (incoming requests)
    }

    private func sendRequest(type: MessageType, payload: Data) async throws -> Data {
        guard isConnected, let connection else {
            throw CacheConnectionError.notConnected
        }

        let messageId = UUID()
        let message = Message(id: messageId, type: type.rawValue, payload: payload)
        let messageData = try JSONEncoder().encode(message)

        // Prepare length header
        var length = UInt32(messageData.count)
        let lengthData = withUnsafeBytes(of: &length) { Data($0) }

        // Send length + message
        let fullData = lengthData + messageData

        return try await withCheckedThrowingContinuation { continuation in
            // Register response handler
            responseHandlers[messageId] = { result in
                continuation.resume(with: result)
            }

            // Send data
            connection.send(content: fullData, completion: .contentProcessed { [weak self] error in
                if let error {
                    Task { [weak self] in
                        await self?.removeResponseHandler(for: messageId)
                        continuation.resume(throwing: error)
                    }
                }
            })

            // Set timeout
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
                if self.responseHandlers.removeValue(forKey: messageId) != nil {
                    continuation.resume(throwing: CacheConnectionError.timeout)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func removeResponseHandler(for messageId: UUID) {
        responseHandlers.removeValue(forKey: messageId)
    }
}

// MARK: - Errors

public enum CacheConnectionError: Error {
    case invalidKey
    case invalidEndpoint
    case notConnected
    case connectionClosed
    case timeout
    case incompleteData
    case remoteError(String)
}

// MARK: - Mock Implementation for Testing

#if DEBUG
    public actor MockCacheConnection {
        private var storage: [String: Data] = [:]
        private let endpoint: String

        public init(endpoint: String) {
            self.endpoint = endpoint
        }

        public func get(key: String) async throws -> Data? {
            storage[key]
        }

        public func set(key: String, data: Data, ttl _: TimeInterval?) async throws {
            storage[key] = data
        }

        public func remove(key: String) async throws {
            storage.removeValue(forKey: key)
        }

        public func setMultiple(_ values: [String: some Codable], ttl _: TimeInterval?) async throws {
            for (key, value) in values {
                let data = try JSONEncoder().encode(value)
                storage[key] = data
            }
        }

        public func sendHeartbeat(from _: String, keyCount _: Int, load _: Double) async throws {
            // Mock implementation
        }

        public func exchangeNodeInfo(nodeId _: String, endpoint _: String) async throws -> [String: CacheConnection.NodeInfo] {
            // Mock implementation
            [:]
        }

        public func close() {
            // Mock implementation
        }
    }
#endif
