import Foundation

// MARK: - Batch Operation Types

/// Handle for tracking batch operations
public struct BatchOperationHandle: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let operationId: UUID
    public let type: BatchOperationType
    public let assetIds: [UUID]
    public let startTime: Date
    
    public init(
        id: UUID = UUID(),
        operationId: UUID,
        type: BatchOperationType,
        assetIds: [UUID] = [],
        startTime: Date = Date()
    ) {
        self.id = id
        self.operationId = operationId
        self.type = type
        self.assetIds = assetIds
        self.startTime = startTime
    }
}

/// Types of batch operations
public enum BatchOperationType: String, Sendable, CaseIterable, Codable {
    case compress
    case resize
    case convert
    case validate
    case backup
    case tag
    case organize
    case export
    case enhance
    case ocr
    
    public var displayName: String {
        switch self {
        case .compress: "Compress"
        case .resize: "Resize"
        case .convert: "Convert"
        case .validate: "Validate"
        case .backup: "Backup"
        case .tag: "Tag"
        case .organize: "Organize"
        case .export: "Export"
        case .enhance: "Enhance"
        case .ocr: "OCR Extract"
        }
    }
}

/// Progress information for batch operations
public struct BatchProgress: Sendable, Codable, Equatable {
    public let operationId: UUID
    public let totalItems: Int
    public let completedItems: Int
    public let failedItems: Int
    public let currentItem: String?
    public let estimatedTimeRemaining: TimeInterval?
    public let bytesProcessed: Int64
    public let totalBytes: Int64
    public let status: BatchOperationStatus
    public let message: String?
    public let timestamp: Date
    
    public init(
        operationId: UUID,
        totalItems: Int,
        completedItems: Int = 0,
        failedItems: Int = 0,
        currentItem: String? = nil,
        estimatedTimeRemaining: TimeInterval? = nil,
        bytesProcessed: Int64 = 0,
        totalBytes: Int64 = 0,
        status: BatchOperationStatus = .pending,
        message: String? = nil,
        timestamp: Date = Date()
    ) {
        self.operationId = operationId
        self.totalItems = totalItems
        self.completedItems = completedItems
        self.failedItems = failedItems
        self.currentItem = currentItem
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.bytesProcessed = bytesProcessed
        self.totalBytes = totalBytes
        self.status = status
        self.message = message
        self.timestamp = timestamp
    }
    
    /// Progress as percentage (0-100)
    public var progressPercentage: Double {
        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems) * 100
    }
    
    /// Bytes progress as percentage (0-100)
    public var bytesProgressPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesProcessed) / Double(totalBytes) * 100
    }
}

/// Status of batch operations
public enum BatchOperationStatus: String, Sendable, CaseIterable, Codable {
    case pending
    case running
    case paused
    case completed
    case failed
    case cancelled
    
    public var displayName: String {
        switch self {
        case .pending: "Pending"
        case .running: "Running"
        case .paused: "Paused"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
    
    public var isActive: Bool {
        switch self {
        case .running, .paused:
            return true
        case .pending, .completed, .failed, .cancelled:
            return false
        }
    }
}

/// Result of individual batch operation items
public struct BatchOperationResult: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let assetId: UUID
    public let operationId: UUID
    public let status: BatchItemStatus
    public let result: String?
    public let error: String?
    public let processingTime: TimeInterval
    public let completedAt: Date?
    
    public init(
        id: UUID = UUID(),
        assetId: UUID,
        operationId: UUID,
        status: BatchItemStatus,
        result: String? = nil,
        error: String? = nil,
        processingTime: TimeInterval = 0,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.assetId = assetId
        self.operationId = operationId
        self.status = status
        self.result = result
        self.error = error
        self.processingTime = processingTime
        self.completedAt = completedAt
    }
}

/// Status of individual batch items
public enum BatchItemStatus: String, Sendable, CaseIterable, Codable {
    case pending
    case processing
    case completed
    case failed
    case skipped
    
    public var displayName: String {
        switch self {
        case .pending: "Pending"
        case .processing: "Processing"
        case .completed: "Completed"
        case .failed: "Failed"
        case .skipped: "Skipped"
        }
    }
}

/// Summary of batch operation
public struct BatchOperationSummary: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let handle: BatchOperationHandle
    public let finalStatus: BatchOperationStatus
    public let totalItems: Int
    public let successfulItems: Int
    public let failedItems: Int
    public let skippedItems: Int
    public let totalProcessingTime: TimeInterval
    public let completedAt: Date?
    public let errors: [String]
    
    public init(
        id: UUID = UUID(),
        handle: BatchOperationHandle,
        finalStatus: BatchOperationStatus,
        totalItems: Int,
        successfulItems: Int = 0,
        failedItems: Int = 0,
        skippedItems: Int = 0,
        totalProcessingTime: TimeInterval = 0,
        completedAt: Date? = nil,
        errors: [String] = []
    ) {
        self.id = id
        self.handle = handle
        self.finalStatus = finalStatus
        self.totalItems = totalItems
        self.successfulItems = successfulItems
        self.failedItems = failedItems
        self.skippedItems = skippedItems
        self.totalProcessingTime = totalProcessingTime
        self.completedAt = completedAt
        self.errors = errors
    }
}

/// Operation priority levels
public enum OperationPriority: String, Sendable, CaseIterable, Codable {
    case low
    case normal
    case high
    case urgent
    
    public var displayName: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        case .urgent: "Urgent"
        }
    }
    
    public var sortValue: Int {
        switch self {
        case .low: 0
        case .normal: 1
        case .high: 2
        case .urgent: 3
        }
    }
}

/// Batch engine configuration settings
public struct BatchEngineSettings: Sendable, Codable, Equatable {
    public let maxConcurrentOperations: Int
    public let maxMemoryUsage: Int64
    public let defaultTimeout: TimeInterval
    public let retryAttempts: Int
    public let enableProgressCallbacks: Bool
    
    public init(
        maxConcurrentOperations: Int = 3,
        maxMemoryUsage: Int64 = 100 * 1024 * 1024, // 100MB
        defaultTimeout: TimeInterval = 300, // 5 minutes
        retryAttempts: Int = 2,
        enableProgressCallbacks: Bool = true
    ) {
        self.maxConcurrentOperations = maxConcurrentOperations
        self.maxMemoryUsage = maxMemoryUsage
        self.defaultTimeout = defaultTimeout
        self.retryAttempts = retryAttempts
        self.enableProgressCallbacks = enableProgressCallbacks
    }
}

/// Batch operation definition
public struct BatchOperation: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let type: BatchOperationType
    public let assetIds: [UUID]
    public let parameters: [String: String]
    public let priority: OperationPriority
    public let settings: BatchEngineSettings?
    
    public init(
        id: UUID = UUID(),
        type: BatchOperationType,
        assetIds: [UUID],
        parameters: [String: String] = [:],
        priority: OperationPriority = .normal,
        settings: BatchEngineSettings? = nil
    ) {
        self.id = id
        self.type = type
        self.assetIds = assetIds
        self.parameters = parameters
        self.priority = priority
        self.settings = settings
    }
}

/// Status tracking for media batch operations in TCA state
public struct MediaBatchOperationStatus: Sendable, Codable, Equatable {
    public let activeOperations: [BatchOperationHandle]
    public let completedOperations: [BatchOperationSummary]
    public let totalItemsProcessing: Int
    public let estimatedTimeRemaining: TimeInterval?
    
    public init(
        activeOperations: [BatchOperationHandle] = [],
        completedOperations: [BatchOperationSummary] = [],
        totalItemsProcessing: Int = 0,
        estimatedTimeRemaining: TimeInterval? = nil
    ) {
        self.activeOperations = activeOperations
        self.completedOperations = completedOperations
        self.totalItemsProcessing = totalItemsProcessing
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}