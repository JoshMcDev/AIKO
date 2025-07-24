import ComposableArchitecture
import Foundation

/// Global actor for scan session operations
@globalActor
public actor ScanActor {
    public static let shared = ScanActor()
}

/// Actor-isolated session engine for thread-safe session management
public actor SessionEngine {
    private var currentSession: ScanSession
    private let autosaveInterval: TimeInterval = 3.0
    private var autosaveTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(initialSession: ScanSession = ScanSession()) {
        currentSession = initialSession
        Task {
            await startAutosave()
        }
    }

    // MARK: - Session Access

    /// Get current session state (immutable copy)
    public var session: ScanSession {
        currentSession
    }

    // MARK: - Page Management

    /// Add a new page to the session
    @discardableResult
    public func addPage(_ page: SessionPage) async throws -> ScanSession {
        var newPage = page
        newPage.order = currentSession.pages.count

        currentSession.pages.append(newPage)
        currentSession.touch()

        await triggerAutosave()
        return currentSession
    }

    /// Remove a page from the session
    @discardableResult
    public func removePage(id: SessionPage.ID) async throws -> ScanSession {
        guard currentSession.pages.contains(where: { $0.id == id }) else {
            throw ScanError.pageNotFound(id)
        }

        currentSession.pages.removeAll { $0.id == id }

        // Reorder remaining pages
        for (index, var page) in currentSession.pages.enumerated() {
            page.order = index
            currentSession.pages[id: page.id] = page
        }

        currentSession.touch()
        await triggerAutosave()
        return currentSession
    }

    /// Reorder pages by providing new order of IDs
    @discardableResult
    public func reorderPages(by pageIDs: [SessionPage.ID]) async throws -> ScanSession {
        guard pageIDs.count == currentSession.pages.count else {
            throw ScanError.invalidPageOrder
        }

        guard Set(pageIDs) == Set(currentSession.pages.ids) else {
            throw ScanError.invalidPageOrder
        }

        var reorderedPages: IdentifiedArrayOf<SessionPage> = []

        for (newOrder, pageID) in pageIDs.enumerated() {
            guard var page = currentSession.pages[id: pageID] else {
                throw ScanError.pageNotFound(pageID)
            }
            page.order = newOrder
            reorderedPages.append(page)
        }

        currentSession.pages = reorderedPages
        currentSession.touch()

        await triggerAutosave()
        return currentSession
    }

    /// Update page processing status
    @discardableResult
    public func updatePageStatus(id: SessionPage.ID, status: PageProcessingStatus) async throws -> ScanSession {
        guard currentSession.pages[id: id] != nil else {
            throw ScanError.pageNotFound(id)
        }

        currentSession.pages[id: id]?.processingStatus = status
        currentSession.touch()

        // Update batch operation state if in progress
        if case let .inProgress(_, total) = currentSession.batchOperationState {
            let completed = currentSession.processedPageCount

            if completed == total {
                currentSession.batchOperationState = .completed(total: total)
                currentSession.status = .completed
            } else {
                currentSession.batchOperationState = .inProgress(completedCount: completed, total: total)
            }
        }

        await triggerAutosave()
        return currentSession
    }

    // MARK: - Batch Operations

    /// Start batch processing of all pending pages
    @discardableResult
    public func startBatchProcessing() async throws -> ScanSession {
        guard currentSession.status.isActive else {
            throw ScanError.processingFailed("Session is not in active state")
        }

        let total = currentSession.pages.count
        let completed = currentSession.processedPageCount

        currentSession.status = .processing
        currentSession.batchOperationState = .inProgress(completedCount: completed, total: total)
        currentSession.touch()

        await triggerAutosave()
        return currentSession
    }

    /// Pause batch processing
    @discardableResult
    public func pauseBatchProcessing() async throws -> ScanSession {
        if case let .inProgress(completed, total) = currentSession.batchOperationState {
            currentSession.batchOperationState = .paused(completedCount: completed, total: total)
            currentSession.status = .ready
            currentSession.touch()

            await triggerAutosave()
        }
        return currentSession
    }

    /// Resume batch processing
    @discardableResult
    public func resumeBatchProcessing() async throws -> ScanSession {
        if case let .paused(completed, total) = currentSession.batchOperationState {
            currentSession.batchOperationState = .inProgress(completedCount: completed, total: total)
            currentSession.status = .processing
            currentSession.touch()

            await triggerAutosave()
        }
        return currentSession
    }

    /// Mark batch processing as failed
    @discardableResult
    public func failBatchProcessing(error: String) async throws -> ScanSession {
        if case let .inProgress(completed, total) = currentSession.batchOperationState {
            currentSession.batchOperationState = .failed(completedCount: completed, total: total, error: error)
            currentSession.status = .failed
            currentSession.lastError = .batchOperationFailed(error)
            currentSession.touch()

            await triggerAutosave()
        }
        return currentSession
    }

    // MARK: - Session Management

    /// Update session status
    @discardableResult
    public func updateStatus(_ status: SessionStatus) async -> ScanSession {
        currentSession.status = status
        currentSession.touch()

        await triggerAutosave()
        return currentSession
    }

    /// Set session error
    @discardableResult
    public func setError(_ error: ScanError) async -> ScanSession {
        currentSession.lastError = error
        currentSession.status = .failed
        currentSession.touch()

        await triggerAutosave()
        return currentSession
    }

    /// Clear session error
    @discardableResult
    public func clearError() async -> ScanSession {
        currentSession.lastError = nil
        if currentSession.status == .failed {
            currentSession.status = .ready
        }
        currentSession.touch()

        await triggerAutosave()
        return currentSession
    }

    /// Replace entire session (for recovery)
    @discardableResult
    public func replaceSession(_ newSession: ScanSession) async -> ScanSession {
        currentSession = newSession
        currentSession.status = .recovered
        currentSession.touch()

        await triggerAutosave()
        return currentSession
    }

    // MARK: - Autosave

    private func startAutosave() {
        autosaveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(autosaveInterval * 1_000_000_000))

                if !Task.isCancelled {
                    await performAutosave()
                }
            }
        }
    }

    private func triggerAutosave() async {
        await performAutosave()
    }

    private func performAutosave() async {
        do {
            try await SessionStorage.shared.saveSession(currentSession)
            currentSession.metadata.lastAutosaveCheckpoint = Date()
        } catch {
            print("Autosave failed: \(error)")
        }
    }

    deinit {
        autosaveTask?.cancel()
    }
}

// MARK: - Dependency Registration

extension SessionEngine: DependencyKey {
    public static let liveValue: SessionEngine = .init()
    public static let testValue: SessionEngine = .init()
}

public extension DependencyValues {
    var sessionEngine: SessionEngine {
        get { self[SessionEngine.self] }
        set { self[SessionEngine.self] = newValue }
    }
}

// MARK: - Session Storage

/// Secure session storage service
public actor SessionStorage {
    public static let shared = SessionStorage()

    private let fileManager = FileManager.default

    private var storageURL: URL {
        guard let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("Unable to access caches directory")
        }
        return cacheURL.appendingPathComponent("ScanSessions")
    }

    private init() {
        Task {
            await ensureStorageDirectoryExists()
        }
    }

    private func ensureStorageDirectoryExists() async {
        try? fileManager.createDirectory(at: storageURL, withIntermediateDirectories: true)
    }

    /// Save session to persistent storage
    public func saveSession(_ session: ScanSession) async throws {
        await ensureStorageDirectoryExists()

        let sessionURL = storageURL.appendingPathComponent("session-\(session.id.uuidString).json")
        let latestURL = storageURL.appendingPathComponent("latest-session.json")

        do {
            let data = try JSONEncoder().encode(session)
            try data.write(to: sessionURL)
            try data.write(to: latestURL) // Keep latest session for quick recovery
        } catch {
            throw ScanError.storageError("Failed to save session: \(error.localizedDescription)")
        }
    }

    /// Load specific session
    public func loadSession(id: UUID) async throws -> ScanSession {
        let sessionURL = storageURL.appendingPathComponent("session-\(id.uuidString).json")

        do {
            let data = try Data(contentsOf: sessionURL)
            return try JSONDecoder().decode(ScanSession.self, from: data)
        } catch {
            throw ScanError.storageError("Failed to load session: \(error.localizedDescription)")
        }
    }

    /// Load latest session for recovery
    public func loadLatestSession() async throws -> ScanSession? {
        let latestURL = storageURL.appendingPathComponent("latest-session.json")

        guard fileManager.fileExists(atPath: latestURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: latestURL)
            return try JSONDecoder().decode(ScanSession.self, from: data)
        } catch {
            // If latest session is corrupted, clean it up
            try? fileManager.removeItem(at: latestURL)
            return nil
        }
    }

    /// Delete session from storage
    public func deleteSession(id: UUID) async throws {
        let sessionURL = storageURL.appendingPathComponent("session-\(id.uuidString).json")

        do {
            try fileManager.removeItem(at: sessionURL)
        } catch {
            throw ScanError.storageError("Failed to delete session: \(error.localizedDescription)")
        }
    }

    /// List all stored session IDs
    public func listSessionIDs() async throws -> [UUID] {
        await ensureStorageDirectoryExists()

        do {
            let contents = try fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
            return contents.compactMap { url in
                let filename = url.lastPathComponent
                guard filename.hasPrefix("session-"), filename.hasSuffix(".json") else { return nil }

                let uuidString = String(filename.dropFirst(8).dropLast(5)) // Remove "session-" and ".json"
                return UUID(uuidString: uuidString)
            }
        } catch {
            throw ScanError.storageError("Failed to list sessions: \(error.localizedDescription)")
        }
    }

    /// Clear all stored sessions
    public func clearAllSessions() async throws {
        do {
            let contents = try fileManager.contentsOfDirectory(at: storageURL, includingPropertiesForKeys: nil)
            for url in contents {
                try fileManager.removeItem(at: url)
            }
        } catch {
            throw ScanError.storageError("Failed to clear sessions: \(error.localizedDescription)")
        }
    }
}
