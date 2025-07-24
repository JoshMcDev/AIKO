import Dependencies
import Foundation

// MARK: - FilePickerClient

public struct FilePickerClient: Sendable {
    public var pickFile: @Sendable () async throws -> MediaAsset
    public var pickMultipleFiles: @Sendable () async throws -> [MediaAsset]
    public var supportedFileTypes: @Sendable () -> [String]

    public init(
        pickFile: @escaping @Sendable () async throws -> MediaAsset,
        pickMultipleFiles: @escaping @Sendable () async throws -> [MediaAsset],
        supportedFileTypes: @escaping @Sendable () -> [String]
    ) {
        self.pickFile = pickFile
        self.pickMultipleFiles = pickMultipleFiles
        self.supportedFileTypes = supportedFileTypes
    }
}

extension FilePickerClient: DependencyKey {
    public static let liveValue = FilePickerClient(
        pickFile: { throw NSError(domain: "NotImplemented", code: -1) },
        pickMultipleFiles: { throw NSError(domain: "NotImplemented", code: -1) },
        supportedFileTypes: { [] }
    )
}

// MARK: - PhotoLibraryClient

public struct PhotoLibraryClient: Sendable {
    public var pickPhoto: @Sendable () async throws -> MediaAsset
    public var pickMultiplePhotos: @Sendable () async throws -> [MediaAsset]
    public var requestAccess: @Sendable () async -> Bool

    public init(
        pickPhoto: @escaping @Sendable () async throws -> MediaAsset,
        pickMultiplePhotos: @escaping @Sendable () async throws -> [MediaAsset],
        requestAccess: @escaping @Sendable () async -> Bool
    ) {
        self.pickPhoto = pickPhoto
        self.pickMultiplePhotos = pickMultiplePhotos
        self.requestAccess = requestAccess
    }
}

extension PhotoLibraryClient: DependencyKey {
    public static let liveValue = PhotoLibraryClient(
        pickPhoto: { throw NSError(domain: "NotImplemented", code: -1) },
        pickMultiplePhotos: { throw NSError(domain: "NotImplemented", code: -1) },
        requestAccess: { false }
    )
}

// MARK: - ScreenshotClient

public struct ScreenshotClient: Sendable {
    public var captureScreen: @Sendable () async throws -> MediaAsset
    public var startRecording: @Sendable () async throws -> Void
    public var stopRecording: @Sendable () async throws -> MediaAsset
    public var requestAccess: @Sendable () async -> Bool

    public init(
        captureScreen: @escaping @Sendable () async throws -> MediaAsset,
        startRecording: @escaping @Sendable () async throws -> Void,
        stopRecording: @escaping @Sendable () async throws -> MediaAsset,
        requestAccess: @escaping @Sendable () async -> Bool
    ) {
        self.captureScreen = captureScreen
        self.startRecording = startRecording
        self.stopRecording = stopRecording
        self.requestAccess = requestAccess
    }
}

extension ScreenshotClient: DependencyKey {
    public static let liveValue = ScreenshotClient(
        captureScreen: { throw NSError(domain: "NotImplemented", code: -1) },
        startRecording: { throw NSError(domain: "NotImplemented", code: -1) },
        stopRecording: { throw NSError(domain: "NotImplemented", code: -1) },
        requestAccess: { false }
    )
}

// MARK: - MediaValidationClient

public struct MediaValidationClient: Sendable {
    public var validateFile: @Sendable (URL) async throws -> MediaClientValidationResult
    public var validateFileSize: @Sendable (Int64) -> MediaClientValidationResult
    public var validateMimeType: @Sendable (String) -> MediaClientValidationResult
    public var scanForMalware: @Sendable (URL) async throws -> MediaClientValidationResult

    public init(
        validateFile: @escaping @Sendable (URL) async throws -> MediaClientValidationResult,
        validateFileSize: @escaping @Sendable (Int64) -> MediaClientValidationResult,
        validateMimeType: @escaping @Sendable (String) -> MediaClientValidationResult,
        scanForMalware: @escaping @Sendable (URL) async throws -> MediaClientValidationResult
    ) {
        self.validateFile = validateFile
        self.validateFileSize = validateFileSize
        self.validateMimeType = validateMimeType
        self.scanForMalware = scanForMalware
    }
}

extension MediaValidationClient: DependencyKey {
    public static let liveValue = MediaValidationClient(
        validateFile: { _ in MediaClientValidationResult(isValid: true) },
        validateFileSize: { _ in MediaClientValidationResult(isValid: true) },
        validateMimeType: { _ in MediaClientValidationResult(isValid: true) },
        scanForMalware: { _ in MediaClientValidationResult(isValid: true) }
    )
}

// MARK: - MediaMetadataClient

public struct MediaMetadataClient: Sendable {
    public var extractMetadata: @Sendable (URL) async throws -> MediaMetadata
    public var extractEXIF: @Sendable (URL) async throws -> [String: String]
    public var generateThumbnail: @Sendable (URL) async throws -> Data

    public init(
        extractMetadata: @escaping @Sendable (URL) async throws -> MediaMetadata,
        extractEXIF: @escaping @Sendable (URL) async throws -> [String: String],
        generateThumbnail: @escaping @Sendable (URL) async throws -> Data
    ) {
        self.extractMetadata = extractMetadata
        self.extractEXIF = extractEXIF
        self.generateThumbnail = generateThumbnail
    }
}

extension MediaMetadataClient: DependencyKey {
    public static let liveValue = MediaMetadataClient(
        extractMetadata: { _ in MediaMetadata() },
        extractEXIF: { _ in [:] },
        generateThumbnail: { _ in Data() }
    )
}

// MARK: - Dependency Extensions

public extension DependencyValues {
    var filePickerClient: FilePickerClient {
        get { self[FilePickerClient.self] }
        set { self[FilePickerClient.self] = newValue }
    }

    var photoLibraryClient: PhotoLibraryClient {
        get { self[PhotoLibraryClient.self] }
        set { self[PhotoLibraryClient.self] = newValue }
    }

    var screenshotClient: ScreenshotClient {
        get { self[ScreenshotClient.self] }
        set { self[ScreenshotClient.self] = newValue }
    }

    var mediaValidationClient: MediaValidationClient {
        get { self[MediaValidationClient.self] }
        set { self[MediaValidationClient.self] = newValue }
    }

    var mediaMetadataClient: MediaMetadataClient {
        get { self[MediaMetadataClient.self] }
        set { self[MediaMetadataClient.self] = newValue }
    }
}
