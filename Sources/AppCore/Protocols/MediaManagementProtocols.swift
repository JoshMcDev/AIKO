import Combine
import Foundation
import SwiftUI

// MARK: - Batch Processing Protocol

/// Protocol for batch processing engine implementations
public protocol BatchProcessingEngineProtocol: Actor {
    /// Start a new batch operation
    func startBatchOperation(_ operation: BatchOperation) async throws -> BatchOperationHandle

    /// Pause an active operation
    func pauseOperation(_ handle: BatchOperationHandle) async throws

    /// Resume a paused operation
    func resumeOperation(_ handle: BatchOperationHandle) async throws

    /// Cancel an operation
    func cancelOperation(_ handle: BatchOperationHandle) async throws

    /// Get the current status of an operation
    func getOperationStatus(_ handle: BatchOperationHandle) async -> MediaBatchOperationStatus

    /// Get progress information for an operation
    func getOperationProgress(_ handle: BatchOperationHandle) async -> BatchProgress

    /// Get results of completed operation items
    func getOperationResults(_ handle: BatchOperationHandle) async -> [BatchOperationResult]

    /// Monitor progress updates for an operation
    func monitorProgress(_ handle: BatchOperationHandle) -> AsyncStream<BatchProgress>

    /// Set operation priority
    func setOperationPriority(_ handle: BatchOperationHandle, priority: OperationPriority) async throws

    /// Get list of active operations
    func getActiveOperations() async -> [BatchOperationHandle]

    /// Get operation history
    func getOperationHistory(limit: Int) async -> [BatchOperationSummary]

    /// Clear completed operations from history
    func clearCompletedOperations() async

    /// Configure engine settings
    func configureEngine(_ settings: BatchEngineSettings) async
}

// MARK: - File Picker Service Protocol

/// Protocol for file picker service implementations
public protocol FilePickerServiceProtocol: Actor {
    /// Present file picker with options
    func presentFilePicker(options: FilePickerOptions) async throws -> FilePickerResult

    /// Get supported file types
    func getSupportedTypes() async -> [UTType]

    /// Check if type is supported
    func isTypeSupported(_ type: UTType) async -> Bool

    /// Set default options
    func setDefaultOptions(_ options: FilePickerOptions) async

    /// Get current options
    func getCurrentOptions() async -> FilePickerOptions
}

// MARK: - Media Metadata Service Protocol

/// Protocol for media metadata extraction service
public protocol MediaMetadataServiceProtocol: Actor {
    /// Extract metadata from media data
    func extractMetadata(from data: Data, type: MediaType) async throws -> [MetadataField]

    /// Get image dimensions
    func getImageDimensions(from data: Data) async throws -> CGSize

    /// Extract text using OCR
    func extractText(from data: Data) async throws -> [ExtractedText]

    /// Detect faces in image
    func detectFaces(in data: Data) async throws -> [DetectedFace]

    /// Perform comprehensive image analysis
    func analyzeImage(_ data: Data) async throws -> ImageAnalysis

    /// Validate metadata extraction results
    func validateMetadata(_ metadata: [MetadataField]) async -> MediaValidationResult
}

// MARK: - Media Workflow Coordinator Protocol

/// Protocol for coordinating media workflows
public protocol MediaWorkflowCoordinatorProtocol: Actor {
    /// Execute a workflow
    func executeWorkflow(_ workflow: MediaWorkflow) async throws -> WorkflowExecutionHandle

    /// Get workflow definitions
    func getWorkflowDefinitions() async -> [WorkflowDefinition]

    /// Create workflow from template
    func createWorkflowFromTemplate(_ template: WorkflowTemplate) async throws -> MediaWorkflow

    /// Monitor workflow execution
    func monitorExecution(_ handle: WorkflowExecutionHandle) -> AsyncStream<WorkflowExecutionUpdate>

    /// Pause workflow execution
    func pauseExecution(_ handle: WorkflowExecutionHandle) async throws

    /// Resume workflow execution
    func resumeExecution(_ handle: WorkflowExecutionHandle) async throws

    /// Cancel workflow execution
    func cancelExecution(_ handle: WorkflowExecutionHandle) async throws

    /// Get execution status
    func getExecutionStatus(_ handle: WorkflowExecutionHandle) async throws -> WorkflowExecutionStatus

    /// Get execution results
    func getExecutionResults(_ handle: WorkflowExecutionHandle) async throws -> WorkflowExecutionResult

    /// Get available templates
    func getAvailableTemplates() async -> [WorkflowTemplate]

    /// Get workflow categories
    func getWorkflowCategories() async -> [WorkflowCategory]

    /// Get workflow history
    func getWorkflowHistory(limit: Int) async -> [WorkflowExecutionResult]

    /// Validate workflow definition
    func validateWorkflow(_ definition: WorkflowDefinition) async -> WorkflowValidationResult
}

// MARK: - Camera Service Protocol

/// Authorization status for microphone access
public enum MicrophoneAuthorizationStatus: String, Sendable, CaseIterable {
    case notDetermined
    case denied
    case authorized

    public var displayName: String {
        switch self {
        case .notDetermined: "Not Determined"
        case .denied: "Denied"
        case .authorized: "Authorized"
        }
    }
}

/// Camera capture configuration
public struct CameraCaptureConfig: Sendable {
    public let quality: CameraQuality
    public let flashMode: CameraFlashMode
    public let enableLocation: Bool
    public let enableStabilization: Bool

    public init(
        quality: CameraQuality = .high,
        flashMode: CameraFlashMode = .auto,
        enableLocation: Bool = false,
        enableStabilization: Bool = true
    ) {
        self.quality = quality
        self.flashMode = flashMode
        self.enableLocation = enableLocation
        self.enableStabilization = enableStabilization
    }
}

public enum CameraQuality: String, Sendable, CaseIterable {
    case low
    case medium
    case high
    case max

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .max: "Maximum"
        }
    }
}

public enum CameraFlashMode: String, Sendable, CaseIterable {
    case auto
    case on
    case off

    public var displayName: String {
        switch self {
        case .auto: "Auto"
        case .on: "On"
        case .off: "Off"
        }
    }
}

/// Protocol for camera service implementations
public protocol CameraServiceProtocol: Actor {
    /// Check camera authorization status
    func checkCameraAuthorization() async -> Bool

    /// Request camera access
    func requestCameraAccess() async -> Bool

    /// Check microphone authorization status
    func checkMicrophoneAuthorization() async -> MicrophoneAuthorizationStatus

    /// Request microphone access
    func requestMicrophoneAccess() async -> Bool

    /// Capture a photo with the given configuration
    func capturePhoto(config: CameraCaptureConfig) async throws -> Data

    /// Start video recording
    func startVideoRecording(config: CameraCaptureConfig) async throws -> String

    /// Stop video recording and return file path
    func stopVideoRecording() async throws -> URL

    /// Check if camera is available
    func isCameraAvailable() async -> Bool

    /// Get available camera positions
    func getAvailableCameraPositions() async -> [String]

    /// Switch camera position
    func switchCameraPosition(_ position: String) async throws
}

// MARK: - Photo Library Service Protocol

/// Authorization status for photo library access
public enum PhotoLibraryAuthorizationStatus: String, Sendable, CaseIterable {
    case notDetermined
    case denied
    case authorized
    case limited

    public var displayName: String {
        switch self {
        case .notDetermined: "Not Determined"
        case .denied: "Denied"
        case .authorized: "Authorized"
        case .limited: "Limited"
        }
    }
}

/// Photo media type filter
public enum PhotoMediaType: String, Sendable, CaseIterable {
    case image
    case video
    case livePhoto
    case audio

    public var displayName: String {
        switch self {
        case .image: "Images"
        case .video: "Videos"
        case .livePhoto: "Live Photos"
        case .audio: "Audio"
        }
    }
}

/// Photo sort order
public enum PhotoSortOrder: String, Sendable, CaseIterable {
    case newest
    case oldest
    case name
    case size

    public var displayName: String {
        switch self {
        case .newest: "Newest First"
        case .oldest: "Oldest First"
        case .name: "By Name"
        case .size: "By Size"
        }
    }
}

/// Album type filter
public enum AlbumType: String, Sendable, CaseIterable {
    case userCreated
    case smartAlbum
    case syncedAlbum
    case cloudSharedAlbum

    public var displayName: String {
        switch self {
        case .userCreated: "User Created"
        case .smartAlbum: "Smart Album"
        case .syncedAlbum: "Synced Album"
        case .cloudSharedAlbum: "Shared Album"
        }
    }
}

/// Photo asset representation
public struct PhotoAsset: Sendable, Identifiable {
    public let id: String
    public let mediaType: PhotoMediaType
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let creationDate: Date?
    public let modificationDate: Date?
    public let isFavorite: Bool
    public let duration: TimeInterval?
    public let localIdentifier: String

    public init(
        id: String,
        mediaType: PhotoMediaType,
        pixelWidth: Int,
        pixelHeight: Int,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        isFavorite: Bool = false,
        duration: TimeInterval? = nil,
        localIdentifier: String
    ) {
        self.id = id
        self.mediaType = mediaType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isFavorite = isFavorite
        self.duration = duration
        self.localIdentifier = localIdentifier
    }
}

/// Photo album representation
public struct PhotoAlbum: Sendable, Identifiable, Equatable {
    public let id: String
    public let title: String
    public let assetCount: Int
    public let albumType: AlbumType
    public let localIdentifier: String

    public init(
        id: String,
        title: String,
        assetCount: Int,
        albumType: AlbumType,
        localIdentifier: String
    ) {
        self.id = id
        self.title = title
        self.assetCount = assetCount
        self.albumType = albumType
        self.localIdentifier = localIdentifier
    }
}

/// Export options for photo library
public struct ExportOptions: Sendable {
    public let quality: Double
    public let format: ExportFormat
    public let includeMetadata: Bool
    public let maxDimension: Int?

    public init(
        quality: Double = 1.0,
        format: ExportFormat = .original,
        includeMetadata: Bool = true,
        maxDimension: Int? = nil
    ) {
        self.quality = quality
        self.format = format
        self.includeMetadata = includeMetadata
        self.maxDimension = maxDimension
    }

    public enum ExportFormat: String, Sendable, CaseIterable {
        case original
        case jpeg
        case png
        case heif

        public var displayName: String {
            switch self {
            case .original: "Original"
            case .jpeg: "JPEG"
            case .png: "PNG"
            case .heif: "HEIF"
            }
        }
    }
}

/// Protocol for photo library service implementations
public protocol PhotoLibraryServiceProtocol: Actor {
    /// Request photo library authorization
    func requestAuthorization() async throws -> PhotoLibraryAuthorizationStatus

    /// Get current authorization status
    func getAuthorizationStatus() async -> PhotoLibraryAuthorizationStatus

    /// Fetch photos with filters
    func fetchPhotos(
        mediaTypes: Set<PhotoMediaType>,
        limit: Int?,
        sortOrder: PhotoSortOrder
    ) async throws -> [PhotoAsset]

    /// Fetch albums
    func fetchAlbums(types: Set<AlbumType>) async throws -> [PhotoAlbum]

    /// Fetch photos from album
    func fetchPhotosFromAlbum(_ album: PhotoAlbum) async throws -> [PhotoAsset]

    /// Export asset data
    func exportAssetData(_ asset: PhotoAsset, options: ExportOptions) async throws -> Data

    /// Save image to photo library
    func saveImageToLibrary(_ data: Data) async throws -> String

    /// Save video to photo library
    func saveVideoToLibrary(_ url: URL) async throws -> String

    /// Delete assets
    func deleteAssets(_ assets: [PhotoAsset]) async throws

    /// Check if asset exists
    func assetExists(_ localIdentifier: String) async -> Bool
}

// MARK: - Screenshot Service Protocol

/// Screenshot result
public struct ScreenshotResult: Sendable {
    public let imageData: Data
    public let captureDate: Date
    public let dimensions: CGSize
    public let scaleFactor: Double

    public init(
        imageData: Data,
        captureDate: Date = Date(),
        dimensions: CGSize,
        scaleFactor: Double = 1.0
    ) {
        self.imageData = imageData
        self.captureDate = captureDate
        self.dimensions = dimensions
        self.scaleFactor = scaleFactor
    }
}

/// Screen recording options
public struct ScreenRecordingOptions: Sendable {
    public let enableMicrophone: Bool
    public let quality: RecordingQuality
    public let frameRate: Int

    public init(
        enableMicrophone: Bool = false,
        quality: RecordingQuality = .high,
        frameRate: Int = 30
    ) {
        self.enableMicrophone = enableMicrophone
        self.quality = quality
        self.frameRate = frameRate
    }

    public enum RecordingQuality: String, Sendable, CaseIterable {
        case low
        case medium
        case high
        case max

        public var displayName: String {
            switch self {
            case .low: "Low"
            case .medium: "Medium"
            case .high: "High"
            case .max: "Maximum"
            }
        }
    }
}

/// Screen recording session
public struct ScreenRecordingSession: Sendable, Identifiable {
    public let id: String
    public let startTime: Date
    public let options: ScreenRecordingOptions

    public init(
        id: String = UUID().uuidString,
        startTime: Date = Date(),
        options: ScreenRecordingOptions
    ) {
        self.id = id
        self.startTime = startTime
        self.options = options
    }
}

/// Screen recording result
public struct ScreenRecordingResult: Sendable {
    public let videoURL: URL
    public let duration: TimeInterval
    public let fileSize: Int64
    public let session: ScreenRecordingSession

    public init(
        videoURL: URL,
        duration: TimeInterval,
        fileSize: Int64,
        session: ScreenRecordingSession
    ) {
        self.videoURL = videoURL
        self.duration = duration
        self.fileSize = fileSize
        self.session = session
    }
}

/// Window information
public struct WindowInfo: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let bundleIdentifier: String
    public let frame: CGRect

    public init(
        id: String,
        title: String,
        bundleIdentifier: String,
        frame: CGRect
    ) {
        self.id = id
        self.title = title
        self.bundleIdentifier = bundleIdentifier
        self.frame = frame
    }
}

/// Protocol for screenshot service implementations
public protocol ScreenshotServiceProtocol: Actor {
    /// Capture full screen screenshot
    func captureScreen() async throws -> ScreenshotResult

    /// Capture specific area screenshot
    func captureArea(_ rect: CGRect) async throws -> ScreenshotResult

    /// Capture view screenshot
    func captureView(_ view: AnyView) async throws -> ScreenshotResult

    /// Start screen recording
    func startScreenRecording(options: ScreenRecordingOptions) async throws -> ScreenRecordingSession

    /// Stop screen recording
    func stopScreenRecording(_ session: ScreenRecordingSession) async throws -> ScreenRecordingResult

    /// Get available windows
    func getAvailableWindows() async throws -> [WindowInfo]

    /// Capture window screenshot
    func captureWindow(_ windowInfo: WindowInfo) async throws -> ScreenshotResult

    /// Check screen recording permission
    func checkScreenRecordingPermission() async -> Bool

    /// Request screen recording permission
    func requestScreenRecordingPermission() async -> Bool
}

// MARK: - Validation Service Protocol

/// Validation rules for media content
public struct ValidationRules: Sendable {
    public let maxFileSize: Int64
    public let allowedMimeTypes: Set<String>
    public let requireMetadata: Bool
    public let enforceDimensions: Bool
    public let dimensionConstraints: DimensionConstraints?
    public let sizeConstraints: SizeConstraints?

    public init(
        maxFileSize: Int64 = 100 * 1024 * 1024, // 100MB
        allowedMimeTypes: Set<String> = ["image/jpeg", "image/png", "video/mp4"],
        requireMetadata: Bool = false,
        enforceDimensions: Bool = false,
        dimensionConstraints: DimensionConstraints? = nil,
        sizeConstraints: SizeConstraints? = nil
    ) {
        self.maxFileSize = maxFileSize
        self.allowedMimeTypes = allowedMimeTypes
        self.requireMetadata = requireMetadata
        self.enforceDimensions = enforceDimensions
        self.dimensionConstraints = dimensionConstraints
        self.sizeConstraints = sizeConstraints
    }
}

/// Size constraints for validation
public struct SizeConstraints: Sendable {
    public let minSize: Int64
    public let maxSize: Int64

    public init(minSize: Int64, maxSize: Int64) {
        self.minSize = minSize
        self.maxSize = maxSize
    }
}

/// Dimension constraints for validation
public struct DimensionConstraints: Sendable {
    public let minWidth: Int
    public let maxWidth: Int
    public let minHeight: Int
    public let maxHeight: Int
    public let aspectRatios: [Double]?

    public init(
        minWidth: Int = 1,
        maxWidth: Int = 8192,
        minHeight: Int = 1,
        maxHeight: Int = 8192,
        aspectRatios: [Double]? = nil
    ) {
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.aspectRatios = aspectRatios
    }
}

/// Media dimensions
public struct MediaDimensions: Sendable {
    public let width: Int
    public let height: Int
    public let aspectRatio: Double

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        aspectRatio = height > 0 ? Double(width) / Double(height) : 0
    }
}

/// Integrity check result
public struct IntegrityCheckResult: Sendable {
    public let isValid: Bool
    public let issues: [IntegrityIssue]
    public let checksum: String?

    public init(
        isValid: Bool,
        issues: [IntegrityIssue] = [],
        checksum: String? = nil
    ) {
        self.isValid = isValid
        self.issues = issues
        self.checksum = checksum
    }

    public struct IntegrityIssue: Sendable {
        public let severity: Severity
        public let description: String

        public init(severity: Severity, description: String) {
            self.severity = severity
            self.description = description
        }

        public enum Severity: String, Sendable, CaseIterable {
            case warning
            case error
            case critical

            public var displayName: String {
                switch self {
                case .warning: "Warning"
                case .error: "Error"
                case .critical: "Critical"
                }
            }
        }
    }
}

/// Security scan result
public struct SecurityScanResult: Sendable {
    public let isSafe: Bool
    public let threats: [SecurityThreat]
    public let scanDuration: TimeInterval

    public init(
        isSafe: Bool,
        threats: [SecurityThreat] = [],
        scanDuration: TimeInterval
    ) {
        self.isSafe = isSafe
        self.threats = threats
        self.scanDuration = scanDuration
    }

    public struct SecurityThreat: Sendable {
        public let type: ThreatType
        public let severity: Severity
        public let description: String

        public init(type: ThreatType, severity: Severity, description: String) {
            self.type = type
            self.severity = severity
            self.description = description
        }

        public enum ThreatType: String, Sendable, CaseIterable {
            case malware
            case virus
            case trojan
            case suspicious
            case unknown

            public var displayName: String {
                switch self {
                case .malware: "Malware"
                case .virus: "Virus"
                case .trojan: "Trojan"
                case .suspicious: "Suspicious Content"
                case .unknown: "Unknown Threat"
                }
            }
        }

        public enum Severity: String, Sendable, CaseIterable {
            case low
            case medium
            case high
            case critical

            public var displayName: String {
                switch self {
                case .low: "Low"
                case .medium: "Medium"
                case .high: "High"
                case .critical: "Critical"
                }
            }
        }
    }
}

/// Protocol for validation service implementations
public protocol ValidationServiceProtocol: Actor {
    /// Validate file against rules
    func validateFile(_ data: Data, rules: ValidationRules) async throws -> Bool

    /// Validate file format
    func validateFormat(_ data: Data, expectedMimeType: String) async throws -> Bool

    /// Validate file size
    func validateSize(_ data: Data, constraints: SizeConstraints) async throws -> Bool

    /// Validate media dimensions
    func validateDimensions(_ dimensions: MediaDimensions, constraints: DimensionConstraints) async throws -> Bool

    /// Perform integrity check
    func performIntegrityCheck(_ data: Data) async throws -> IntegrityCheckResult

    /// Perform security scan
    func performSecurityScan(_ data: Data) async throws -> SecurityScanResult

    /// Generate file rules based on content type
    func generateRulesForContentType(_ mimeType: String) async -> ValidationRules

    /// Get default validation rules
    func getDefaultRules() async -> ValidationRules

    /// Validate batch of files
    func validateBatch(_ files: [(Data, ValidationRules)]) async throws -> [Bool]
}
