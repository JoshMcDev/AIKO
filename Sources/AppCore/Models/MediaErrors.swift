import Foundation

// MARK: - Media Error Types

/// Comprehensive error types for media operations
public enum MediaError: Error, Sendable, LocalizedError, Equatable {
    case invalidInput(String)
    case fileNotFound(String)
    case unsupportedFormat(String)
    case processingFailed(String)
    case networkError(String)
    case permissionDenied(String)
    case storageError(String)
    case corruptedData(String)
    case timeout(String)
    case unsupportedOperation(String)
    case configurationError(String)
    case resourceUnavailable(String)
    case authenticationRequired(String)
    case quotaExceeded(String)
    case versionMismatch(String)
    case unknown(String)
    
    // Specific media operation errors
    case filePickingFailed(String)
    case photoLibraryAccessFailed(String)
    case cameraAccessFailed(String)
    case screenshotFailed(String)
    case metadataExtractionFailed(String)
    case validationFailed(String)
    case batchOperationFailed(String)
    case workflowExecutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidInput(message):
            "Invalid input: \(message)"
        case let .fileNotFound(message):
            "File not found: \(message)"
        case let .unsupportedFormat(message):
            "Unsupported format: \(message)"
        case let .processingFailed(message):
            "Processing failed: \(message)"
        case let .networkError(message):
            "Network error: \(message)"
        case let .permissionDenied(message):
            "Permission denied: \(message)"
        case let .storageError(message):
            "Storage error: \(message)"
        case let .corruptedData(message):
            "Corrupted data: \(message)"
        case let .timeout(message):
            "Operation timed out: \(message)"
        case let .unsupportedOperation(message):
            "Unsupported operation: \(message)"
        case let .configurationError(message):
            "Configuration error: \(message)"
        case let .resourceUnavailable(message):
            "Resource unavailable: \(message)"
        case let .authenticationRequired(message):
            "Authentication required: \(message)"
        case let .quotaExceeded(message):
            "Quota exceeded: \(message)"
        case let .versionMismatch(message):
            "Version mismatch: \(message)"
        case let .unknown(message):
            "Unknown error: \(message)"
        case let .filePickingFailed(message):
            "File picking failed: \(message)"
        case let .photoLibraryAccessFailed(message):
            "Photo library access failed: \(message)"
        case let .cameraAccessFailed(message):
            "Camera access failed: \(message)"
        case let .screenshotFailed(message):
            "Screenshot failed: \(message)"
        case let .metadataExtractionFailed(message):
            "Metadata extraction failed: \(message)"
        case let .validationFailed(message):
            "Validation failed: \(message)"
        case let .batchOperationFailed(message):
            "Batch operation failed: \(message)"
        case let .workflowExecutionFailed(message):
            "Workflow execution failed: \(message)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .invalidInput:
            "The provided input data is invalid or malformed"
        case .fileNotFound:
            "The requested file could not be located"
        case .unsupportedFormat:
            "The file format is not supported by this operation"
        case .processingFailed:
            "The media processing operation failed to complete"
        case .networkError:
            "A network connectivity issue occurred"
        case .permissionDenied:
            "Insufficient permissions to perform this operation"
        case .storageError:
            "An error occurred while accessing storage"
        case .corruptedData:
            "The data appears to be corrupted or incomplete"
        case .timeout:
            "The operation took too long to complete"
        case .unsupportedOperation:
            "This operation is not supported in the current context"
        case .configurationError:
            "The system configuration is invalid or incomplete"
        case .resourceUnavailable:
            "The required resource is temporarily unavailable"
        case .authenticationRequired:
            "Authentication is required to access this resource"
        case .quotaExceeded:
            "The operation would exceed available quota limits"
        case .versionMismatch:
            "The data version is incompatible with the current system"
        case .unknown:
            "An unexpected error occurred"
        case .filePickingFailed:
            "The file picker operation failed"
        case .photoLibraryAccessFailed:
            "Unable to access the photo library"
        case .cameraAccessFailed:
            "Camera access was denied or failed"
        case .screenshotFailed:
            "Screenshot capture failed"
        case .metadataExtractionFailed:
            "Failed to extract metadata from media"
        case .validationFailed:
            "Media validation failed"
        case .batchOperationFailed:
            "Batch processing operation failed"
        case .workflowExecutionFailed:
            "Workflow execution encountered an error"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidInput:
            "Please verify the input data and try again"
        case .fileNotFound:
            "Check the file path and ensure the file exists"
        case .unsupportedFormat:
            "Convert the file to a supported format"
        case .processingFailed:
            "Try the operation again or check system resources"
        case .networkError:
            "Check your network connection and retry"
        case .permissionDenied:
            "Grant the necessary permissions and try again"
        case .storageError:
            "Check available storage space and file permissions"
        case .corruptedData:
            "Try using a backup or re-downloading the data"
        case .timeout:
            "Try the operation again or increase timeout settings"
        case .unsupportedOperation:
            "Use an alternative method or update the application"
        case .configurationError:
            "Check system settings and configuration"
        case .resourceUnavailable:
            "Wait a moment and try again"
        case .authenticationRequired:
            "Please authenticate and try again"
        case .quotaExceeded:
            "Free up space or upgrade your plan"
        case .versionMismatch:
            "Update the application or convert the data"
        case .unknown:
            "Contact support if the problem persists"
        case .filePickingFailed:
            "Try selecting files again or check file permissions"
        case .photoLibraryAccessFailed:
            "Grant photo library access in Settings and try again"
        case .cameraAccessFailed:
            "Enable camera permissions in Settings"
        case .screenshotFailed:
            "Try taking the screenshot again"
        case .metadataExtractionFailed:
            "Verify the file is not corrupted and try again"
        case .validationFailed:
            "Check file format and try with a different file"
        case .batchOperationFailed:
            "Retry the batch operation or process files individually"
        case .workflowExecutionFailed:
            "Review workflow settings and try again"
        }
    }
}
