import ComposableArchitecture
import Foundation
import IdentifiedCollections

// MARK: - Media Session Models

/// Immutable session state for media management
public struct MediaSession: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var assets: IdentifiedArrayOf<MediaAsset>
    public var status: MediaSessionStatus
    public var batchOperationState: BatchOperationState
    public var lastError: MediaError?
    public var metadata: MediaSessionMetadata
    public var workflowExecutions: [WorkflowExecutionHandle]
    
    public init(
        id: UUID = UUID(),
        assets: IdentifiedArrayOf<MediaAsset> = [],
        status: MediaSessionStatus = .ready,
        batchOperationState: BatchOperationState = .idle,
        lastError: MediaError? = nil,
        metadata: MediaSessionMetadata = MediaSessionMetadata(),
        workflowExecutions: [WorkflowExecutionHandle] = []
    ) {
        self.id = id
        self.assets = assets
        self.status = status
        self.batchOperationState = batchOperationState
        self.lastError = lastError
        self.metadata = metadata
        self.workflowExecutions = workflowExecutions
    }
}

/// Individual media item within a session
public struct MediaItem: Identifiable, Sendable {
    public let id: UUID
    public var asset: MediaAsset
    public var processingStatus: MediaProcessingStatus
    public var validationResult: MediaValidationResult?
    public var workflowHistory: [WorkflowExecutionHandle]
    public var order: Int
    
    public init(
        id: UUID = UUID(),
        asset: MediaAsset,
        processingStatus: MediaProcessingStatus = .pending,
        validationResult: MediaValidationResult? = nil,
        workflowHistory: [WorkflowExecutionHandle] = [],
        order: Int = 0
    ) {
        self.id = id
        self.asset = asset
        self.processingStatus = processingStatus
        self.validationResult = validationResult
        self.workflowHistory = workflowHistory
        self.order = order
    }
}

/// Session status enumeration
public enum MediaSessionStatus: String, Sendable, CaseIterable, Codable {
    case ready
    case processing
    case paused
    case completed
    case error
    
    public var displayName: String {
        switch self {
        case .ready: "Ready"
        case .processing: "Processing"
        case .paused: "Paused"
        case .completed: "Completed"
        case .error: "Error"
        }
    }
}

/// Media processing status
public enum MediaProcessingStatus: String, Sendable, CaseIterable, Codable {
    case pending
    case processing
    case validating
    case enhancing
    case converting
    case completed
    case failed
    
    public var displayName: String {
        switch self {
        case .pending: "Pending"
        case .processing: "Processing"
        case .validating: "Validating"
        case .enhancing: "Enhancing"
        case .converting: "Converting"
        case .completed: "Completed"
        case .failed: "Failed"
        }
    }
}

/// Session metadata
public struct MediaSessionMetadata: Equatable, Sendable, Codable {
    public let createdAt: Date
    public var lastModified: Date
    public var totalProcessingTime: TimeInterval
    public var sessionTitle: String
    public var tags: [String]
    
    public init(
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        totalProcessingTime: TimeInterval = 0,
        sessionTitle: String = "",
        tags: [String] = []
    ) {
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.totalProcessingTime = totalProcessingTime
        self.sessionTitle = sessionTitle
        self.tags = tags
    }
}

// Note: BatchOperationState is defined in ScanSession.swift

// Note: PhotoAlbum is defined in MediaManagementProtocols.swift