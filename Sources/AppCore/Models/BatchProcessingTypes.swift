import Foundation

// MARK: - Batch Processing Types

// Note: BatchOperation is defined in BatchOperations.swift

/// Individual item within a batch operation
public struct BatchOperationItem: Sendable, Identifiable {
    public let id: UUID
    public let type: String
    public let data: Data?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        type: String,
        data: Data? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.type = type
        self.data = data
        self.metadata = metadata
    }
}

// Note: BatchOperationHandle is defined in BatchOperations.swift

// Note: MediaBatchOperationStatus is defined in BatchOperations.swift

// Note: BatchProgress is defined in BatchOperations.swift

// Note: BatchOperationResult is defined in BatchOperations.swift

// Note: BatchOperationSummary is defined in BatchOperations.swift

// Note: OperationPriority is defined in BatchOperations.swift

// Note: BatchEngineSettings is defined in BatchOperations.swift
