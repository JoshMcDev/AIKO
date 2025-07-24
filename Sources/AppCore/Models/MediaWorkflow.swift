import Foundation
import IdentifiedCollections

// MARK: - Media Workflow Types

/// Represents a media processing workflow
public struct MediaWorkflow: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let steps: [MediaWorkflowStep]
    public let createdAt: Date
    public let modifiedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        steps: [MediaWorkflowStep] = [],
        createdAt: Date = Date(),
        modifiedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.steps = steps
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

/// Individual step in a media workflow
public struct MediaWorkflowStep: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let type: WorkflowStepType
    public let name: String
    public let parameters: [String: String]
    public let order: Int
    
    public init(
        id: UUID = UUID(),
        type: WorkflowStepType,
        name: String,
        parameters: [String: String] = [:],
        order: Int = 0
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.parameters = parameters
        self.order = order
    }
}

/// Types of workflow steps
public enum WorkflowStepType: String, Sendable, CaseIterable, Codable {
    case validate
    case compress
    case resize
    case crop
    case filter
    case enhance
    case ocr
    case export
    case tag
    case organize
    
    public var displayName: String {
        switch self {
        case .validate: "Validate"
        case .compress: "Compress"
        case .resize: "Resize"
        case .crop: "Crop"
        case .filter: "Apply Filter"
        case .enhance: "Enhance"
        case .ocr: "OCR Extract"
        case .export: "Export"
        case .tag: "Add Tags"
        case .organize: "Organize"
        }
    }
}

/// Workflow template for reuse
public struct WorkflowTemplate: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let workflow: MediaWorkflow
    public let category: WorkflowCategory
    public let isSystem: Bool
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        workflow: MediaWorkflow,
        category: WorkflowCategory = .general,
        isSystem: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.workflow = workflow
        self.category = category
        self.isSystem = isSystem
        self.createdAt = createdAt
    }
}

/// Workflow categories for organization
public enum WorkflowCategory: String, Sendable, CaseIterable, Codable {
    case general
    case photography
    case documents
    case videos
    case compression
    case enhancement
    
    public var displayName: String {
        switch self {
        case .general: "General"
        case .photography: "Photography"
        case .documents: "Documents"
        case .videos: "Videos"
        case .compression: "Compression"
        case .enhancement: "Enhancement"
        }
    }
}

/// Workflow execution handle
public struct WorkflowExecutionHandle: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let workflowId: UUID
    public let assetIds: [UUID]
    public let startTime: Date
    
    public init(
        id: UUID = UUID(),
        workflowId: UUID,
        assetIds: [UUID],
        startTime: Date = Date()
    ) {
        self.id = id
        self.workflowId = workflowId
        self.assetIds = assetIds
        self.startTime = startTime
    }
}

/// Workflow execution status
public enum WorkflowExecutionStatus: String, Sendable, CaseIterable, Codable {
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
}

/// Workflow execution result
public struct WorkflowExecutionResult: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let executionHandle: WorkflowExecutionHandle
    public let status: WorkflowExecutionStatus
    public let processedAssets: [UUID]
    public let failedAssets: [UUID]
    public let errors: [String]
    public let duration: TimeInterval
    public let completedAt: Date?
    
    public init(
        id: UUID = UUID(),
        executionHandle: WorkflowExecutionHandle,
        status: WorkflowExecutionStatus,
        processedAssets: [UUID] = [],
        failedAssets: [UUID] = [],
        errors: [String] = [],
        duration: TimeInterval = 0,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.executionHandle = executionHandle
        self.status = status
        self.processedAssets = processedAssets
        self.failedAssets = failedAssets
        self.errors = errors
        self.duration = duration
        self.completedAt = completedAt
    }
}

/// Workflow execution update for monitoring
public struct WorkflowExecutionUpdate: Sendable, Codable, Equatable {
    public let executionId: UUID
    public let status: WorkflowExecutionStatus
    public let currentStep: Int
    public let totalSteps: Int
    public let processedAssets: Int
    public let message: String?
    public let timestamp: Date
    
    public init(
        executionId: UUID,
        status: WorkflowExecutionStatus,
        currentStep: Int,
        totalSteps: Int,
        processedAssets: Int,
        message: String? = nil,
        timestamp: Date = Date()
    ) {
        self.executionId = executionId
        self.status = status
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.processedAssets = processedAssets
        self.message = message
        self.timestamp = timestamp
    }
}

/// Workflow definition for validation
public struct WorkflowDefinition: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let name: String
    public let version: String
    public let requiredSteps: [WorkflowStepType]
    public let supportedFormats: Set<String>
    
    public init(
        id: UUID = UUID(),
        name: String,
        version: String = "1.0",
        requiredSteps: [WorkflowStepType] = [],
        supportedFormats: Set<String> = []
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.requiredSteps = requiredSteps
        self.supportedFormats = supportedFormats
    }
}

/// Workflow validation result
public struct WorkflowValidationResult: Sendable, Codable, Equatable {
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    
    public init(
        isValid: Bool,
        errors: [String] = [],
        warnings: [String] = []
    ) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

