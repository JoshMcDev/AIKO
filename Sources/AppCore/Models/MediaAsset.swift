import Foundation

// MARK: - MediaAsset

public struct MediaAsset: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let type: MediaType
    public let url: URL?
    public let originalURL: URL?
    public let processedURL: URL?
    public var metadata: MediaMetadata
    public let createdAt: Date
    public let size: Int64
    public let fileSize: Int64
    public let mimeType: String

    public init(
        id: UUID = UUID(),
        type: MediaType,
        url: URL? = nil,
        originalURL: URL? = nil,
        processedURL: URL? = nil,
        metadata: MediaMetadata = MediaMetadata(),
        createdAt: Date = Date(),
        size: Int64 = 0,
        fileSize: Int64 = 0,
        mimeType: String = ""
    ) {
        self.id = id
        self.type = type
        self.url = url ?? originalURL
        self.originalURL = originalURL
        self.processedURL = processedURL
        self.metadata = metadata
        self.createdAt = createdAt
        self.size = size > 0 ? size : fileSize
        self.fileSize = fileSize > 0 ? fileSize : size
        self.mimeType = mimeType
    }
}

// MARK: - MediaType

public enum MediaType: String, Sendable, CaseIterable, Codable {
    case image
    case video
    case photo
    case document
    case screenshot
    case camera
    case file
    
    public var displayName: String {
        switch self {
        case .image: "Image"
        case .video: "Video"
        case .photo: "Photo"
        case .document: "Document"
        case .screenshot: "Screenshot"
        case .camera: "Camera"
        case .file: "File"
        }
    }
}

// MARK: - MediaMetadata

public struct MediaMetadata: Sendable, Codable, Equatable {
    public let width: Int?
    public let height: Int?
    public let exifData: [String: String]
    public let location: MediaLocation?
    public let deviceInfo: MediaDeviceInfo?

    public init(
        width: Int? = nil,
        height: Int? = nil,
        exifData: [String: String] = [:],
        location: MediaLocation? = nil,
        deviceInfo: MediaDeviceInfo? = nil
    ) {
        self.width = width
        self.height = height
        self.exifData = exifData
        self.location = location
        self.deviceInfo = deviceInfo
    }
}

// MARK: - Supporting Types

public struct MediaLocation: Sendable, Codable, Equatable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct MediaDeviceInfo: Sendable, Codable, Equatable {
    public let deviceModel: String
    public let osVersion: String
    public let appVersion: String

    public init(deviceModel: String, osVersion: String, appVersion: String) {
        self.deviceModel = deviceModel
        self.osVersion = osVersion
        self.appVersion = appVersion
    }
}

// MARK: - ValidationResult Types
// These types are defined here to avoid conflicts and provide media-specific validation

/// Result of media validation process
public struct MediaValidationResult: Sendable, Equatable {
    public let isValid: Bool
    public let errors: [MediaValidationError]
    public let warnings: [MediaValidationWarning]
    
    public init(isValid: Bool, errors: [MediaValidationError] = [], warnings: [MediaValidationWarning] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// Media validation error
public struct MediaValidationError: Sendable, Equatable {
    public let message: String
    public let code: String?
    
    public init(message: String, code: String? = nil) {
        self.message = message
        self.code = code
    }
}

/// Media validation warning
public struct MediaValidationWarning: Sendable, Equatable {
    public let message: String
    public let suggestion: String?
    
    public init(message: String, suggestion: String? = nil) {
        self.message = message
        self.suggestion = suggestion
    }
}

// Note: Use MediaValidationResult directly instead of ValidationResult to avoid conflicts
