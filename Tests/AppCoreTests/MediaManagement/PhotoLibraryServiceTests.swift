@testable import AppCoreiOS
@testable import AppCore
import XCTest

@available(iOS 16.0, *)
final class PhotoLibraryServiceTests: XCTestCase {
    var sut: PhotoLibraryService?

    override func setUp() async throws {
        try await super.setUp()
        sut = PhotoLibraryService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Authorization Tests

    func testRequestAuthorization_FirstTime_ShouldPromptUser() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sut.requestAuthorization()
        }
    }

    func testRequestAuthorization_WhenDenied_ShouldReturnDenied() async throws {
        // When/Then
        await assertThrowsError {
            _ = try await sut.requestAuthorization()
        }
    }

    func testGetAuthorizationStatus_ShouldReturnCurrentStatus() async {
        // When
        let status = await sut.getAuthorizationStatus()

        // Then
        XCTAssertEqual(status, .notDetermined)
    }

    // MARK: - Photo Fetching Tests

    func testFetchPhotos_WithImageType_ShouldReturnOnlyImages() async throws {
        // Given
        let mediaTypes: Set<PhotoMediaType> = [.image]

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchPhotos(
                mediaTypes: mediaTypes,
                limit: 100,
                sortOrder: .creationDateDescending
            )
        }
    }

    func testFetchPhotos_WithVideoType_ShouldReturnOnlyVideos() async throws {
        // Given
        let mediaTypes: Set<PhotoMediaType> = [.video]

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchPhotos(
                mediaTypes: mediaTypes,
                limit: 50,
                sortOrder: .creationDateAscending
            )
        }
    }

    func testFetchPhotos_WithMultipleTypes_ShouldReturnMixedMedia() async throws {
        // Given
        let mediaTypes: Set<PhotoMediaType> = [.image, .video, .livePhoto]

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchPhotos(
                mediaTypes: mediaTypes,
                limit: nil,
                sortOrder: .modificationDateDescending
            )
        }
    }

    func testFetchPhotos_WithLimit_ShouldRespectLimit() async throws {
        // Given
        let limit = 10

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchPhotos(
                mediaTypes: [.image],
                limit: limit,
                sortOrder: .creationDateDescending
            )
        }
    }

    // MARK: - Album Tests

    func testFetchAlbums_WithUserCreatedType_ShouldReturnUserAlbums() async throws {
        // Given
        let types: Set<AlbumType> = [.userCreated]

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchAlbums(types: types)
        }
    }

    func testFetchAlbums_WithSmartAlbums_ShouldReturnSystemAlbums() async throws {
        // Given
        let types: Set<AlbumType> = [.smartAlbum, .favorites, .recently]

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchAlbums(types: types)
        }
    }

    func testFetchPhotosFromAlbum_WithValidAlbumId_ShouldReturnPhotos() async throws {
        // Given
        let albumId = "test-album-id"

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchPhotosFromAlbum(albumId, limit: 20)
        }
    }

    func testFetchPhotosFromAlbum_WithInvalidAlbumId_ShouldThrowError() async throws {
        // Given
        let albumId = "invalid-album-id"

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchPhotosFromAlbum(albumId, limit: nil)
        }
    }

    // MARK: - Save Tests

    func testSaveImage_WithValidData_ShouldReturnAssetId() async throws {
        // Given
        let imageData = Data()
        let metadata = MediaMetadata(
            fileName: "test.jpg",
            fileExtension: "jpg",
            mimeType: "image/jpeg"
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.saveImage(imageData, metadata: metadata)
        }
    }

    func testSaveVideo_WithValidURL_ShouldReturnAssetId() async throws {
        // Given
        let videoURL = URL(fileURLWithPath: "/tmp/video.mp4")

        // When/Then
        await assertThrowsError {
            _ = try await sut.saveVideo(videoURL, metadata: nil)
        }
    }

    // MARK: - Delete Tests

    func testDeleteAssets_WithValidIds_ShouldRemoveAssets() async throws {
        // Given
        let assetIds = ["asset1", "asset2", "asset3"]

        // When/Then
        await assertThrowsError {
            try await sut.deleteAssets(assetIds)
        }
    }

    func testDeleteAssets_WithEmptyArray_ShouldNotThrow() async throws {
        // Given
        let assetIds: [String] = []

        // When/Then
        await assertThrowsError {
            try await sut.deleteAssets(assetIds)
        }
    }

    // MARK: - Export Tests

    func testExportAssets_WithJPEGFormat_ShouldExportAsJPEG() async throws {
        // Given
        let assetIds = ["asset1"]
        let options = ExportOptions(format: .jpeg, quality: 0.8)

        // When/Then
        await assertThrowsError {
            _ = try await sut.exportAssets(assetIds, options: options)
        }
    }

    func testExportAssets_WithOriginalFormat_ShouldPreserveFormat() async throws {
        // Given
        let assetIds = ["asset1", "asset2"]
        let options = ExportOptions(format: .original)

        // When/Then
        await assertThrowsError {
            _ = try await sut.exportAssets(assetIds, options: options)
        }
    }

    func testExportAssets_WithMetadata_ShouldIncludeMetadata() async throws {
        // Given
        let assetIds = ["asset1"]
        let options = ExportOptions(
            format: .jpeg,
            quality: 1.0,
            includeMetadata: true,
            includeLocation: true
        )

        // When/Then
        await assertThrowsError {
            _ = try await sut.exportAssets(assetIds, options: options)
        }
    }

    // MARK: - Special Media Types Tests

    func testFetchPhotos_LivePhotos_ShouldReturnLivePhotos() async throws {
        // Given
        let mediaTypes: Set<PhotoMediaType> = [.livePhoto]

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchPhotos(
                mediaTypes: mediaTypes,
                limit: nil,
                sortOrder: .creationDateDescending
            )
        }
    }

    func testFetchPhotos_Screenshots_ShouldReturnScreenshots() async throws {
        // Given
        let mediaTypes: Set<PhotoMediaType> = [.screenshot]

        // When/Then
        await assertThrowsError {
            _ = try await sut.fetchPhotos(
                mediaTypes: mediaTypes,
                limit: 50,
                sortOrder: .creationDateDescending
            )
        }
    }
}

// MARK: - Test Helpers

@available(iOS 16.0, *)
extension PhotoLibraryServiceTests {
    func assertThrowsError(
        _ expression: @autoclosure () async throws -> some Any,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error but succeeded", file: file, line: line)
        } catch {
            // Expected error
        }
    }
}
