import AikoCompat
import AppCore
import ComposableArchitecture
import Foundation

/// Configuration for individual document generation
private struct DocumentGenerationConfig: Sendable {
    let documentType: DocumentType
    let requirements: String
    let template: String?
    let systemPrompt: String?
    let profile: UserProfile?
    let aiProvider: any AIProvider
}

/// Configuration for individual D&F document generation
private struct DFDocumentGenerationConfig: Sendable {
    let dfDocumentType: DFDocumentType
    let requirements: String
    let template: DFTemplate?
    let systemPrompt: String?
    let profile: UserProfile?
    let aiProvider: any AIProvider
}

/// Parallel document generation service that processes multiple documents concurrently
public struct ParallelDocumentGenerator: Sendable {
    // MARK: - Configuration

    /// Maximum number of concurrent document generations
    private let maxConcurrency = 4

    /// Batch size for processing documents
    private let batchSize = 3

    // MARK: - Dependencies

    @Dependency(\.aiDocumentGenerator) var aiDocumentGenerator
    @Dependency(\.documentGenerationCache) var cache
    @Dependency(\.standardTemplateService) var templateService
    @Dependency(\.dfTemplateService) var dfTemplateService
    @Dependency(\.userProfileService) var userProfileService
    @Dependency(\.spellCheckService) var spellCheckService
    @Dependency(\.documentGenerationPreloader) var preloader

    // MARK: - Parallel Generation Methods

    /// Generate multiple documents in parallel with optimized batching
    public func generateDocumentsParallel(
        requirements: String,
        documentTypes: Set<DocumentType>,
        profile: UserProfile?
    ) async throws -> [GeneratedDocument] {
        let startTime = Date()
        // Pre-load all required data in parallel
        async let preloadedDataTask = preloader.preloadData(
            for: documentTypes,
            dfDocumentTypes: []
        )

        // Batch check cache for all documents
        async let cachedDocsTask = preloader.preloadCachedDocuments(
            for: documentTypes,
            requirements: requirements,
            profile: profile
        )

        // Await both results
        let (preloadedData, cachedDocs) = try await (preloadedDataTask, cachedDocsTask)

        // Process cached documents
        var cachedDocuments: [GeneratedDocument] = []
        var typesToGenerate: [DocumentType] = []

        for documentType in documentTypes {
            if let content = cachedDocs[documentType] {
                let document = GeneratedDocument(
                    title: "\(documentType.shortName) - \(Date().formatted(date: .abbreviated, time: .omitted))",
                    documentType: documentType,
                    content: content
                )
                cachedDocuments.append(document)
            } else {
                typesToGenerate.append(documentType)
            }
        }

        // Return early if all documents were cached
        if typesToGenerate.isEmpty {
            return cachedDocuments
        }

        // Second pass: Generate missing documents in parallel batches
        let generatedDocuments = try await generateDocumentBatch(
            requirements: requirements,
            documentTypes: typesToGenerate,
            profile: profile ?? preloadedData.profile,
            preloadedData: preloadedData
        )

        // Performance tracking removed for now
        let totalDuration = Date().timeIntervalSince(startTime)
        print("[Performance] Generated \(documentTypes.count) documents in \(totalDuration)s")

        return cachedDocuments + generatedDocuments
    }

    /// Generate D&F documents in parallel
    public func generateDFDocumentsParallel(
        requirements: String,
        dfDocumentTypes: Set<DFDocumentType>,
        profile: UserProfile?
    ) async throws -> [GeneratedDocument] {
        let startTime = Date()
        // Pre-load all required data in parallel
        async let preloadedDataTask = preloader.preloadData(
            for: [],
            dfDocumentTypes: dfDocumentTypes
        )

        // Batch check cache for all documents
        async let cachedDocsTask = preloader.preloadCachedDFDocuments(
            for: dfDocumentTypes,
            requirements: requirements,
            profile: profile
        )

        // Await both results
        let (preloadedData, cachedDocs) = try await (preloadedDataTask, cachedDocsTask)

        // Process cached documents
        var cachedDocuments: [GeneratedDocument] = []
        var typesToGenerate: [DFDocumentType] = []

        for dfDocumentType in dfDocumentTypes {
            if let content = cachedDocs[dfDocumentType] {
                // Cache hit - no additional tracking needed
                let document = GeneratedDocument(
                    title: "\(dfDocumentType.shortName) D&F - \(Date().formatted(date: .abbreviated, time: .omitted))",
                    dfDocumentType: dfDocumentType,
                    content: content
                )
                cachedDocuments.append(document)
            } else {
                typesToGenerate.append(dfDocumentType)
            }
        }

        // Return early if all documents were cached
        if typesToGenerate.isEmpty {
            return cachedDocuments
        }

        // Second pass: Generate missing documents in parallel batches
        let generatedDocuments = try await generateDFDocumentBatch(
            requirements: requirements,
            dfDocumentTypes: typesToGenerate,
            profile: profile ?? preloadedData.profile,
            preloadedData: preloadedData
        )

        // Performance tracking removed for now
        let totalDuration = Date().timeIntervalSince(startTime)
        print("[Performance] Generated \(dfDocumentTypes.count) D&F documents in \(totalDuration)s")

        return cachedDocuments + generatedDocuments
    }

    // MARK: - Private Batch Generation Methods

    private func generateDocumentBatch(
        requirements: String,
        documentTypes: [DocumentType],
        profile: UserProfile?,
        preloadedData: DocumentGenerationPreloader.PreloadedData
    ) async throws -> [GeneratedDocument] {
        guard let aiProvider = await AIProviderFactory.defaultProvider() else {
            throw ParallelDocumentGeneratorError.noProvider
        }

        // Use preloaded templates
        let templates = preloadedData.templates

        // Generate documents in batches
        var allDocuments: [GeneratedDocument] = []

        for batchStart in stride(from: 0, to: documentTypes.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, documentTypes.count)
            let batchTypes = Array(documentTypes[batchStart ..< batchEnd])

            let batchDocuments = try await withThrowingTaskGroup(of: GeneratedDocument?.self) { group in
                for documentType in batchTypes {
                    group.addTask { @Sendable in
                        let provider = aiProvider
                        do {
                            let config = DocumentGenerationConfig(
                                documentType: documentType,
                                requirements: requirements,
                                template: templates[documentType],
                                systemPrompt: preloadedData.systemPrompts[documentType],
                                profile: profile,
                                aiProvider: provider
                            )
                            return try await generateSingleDocument(config: config)
                        } catch {
                            // Log error but don't fail the entire batch
                            print("Error generating \(documentType): \(error)")
                            return nil
                        }
                    }
                }

                var documents: [GeneratedDocument] = []
                for try await document in group {
                    if let doc = document {
                        documents.append(doc)
                    }
                }
                return documents
            }

            allDocuments.append(contentsOf: batchDocuments)

            // Small delay between batches to avoid rate limiting
            if batchEnd < documentTypes.count {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }

        return allDocuments
    }

    private func generateDFDocumentBatch(
        requirements: String,
        dfDocumentTypes: [DFDocumentType],
        profile: UserProfile?,
        preloadedData: DocumentGenerationPreloader.PreloadedData
    ) async throws -> [GeneratedDocument] {
        guard let aiProvider = await AIProviderFactory.defaultProvider() else {
            throw ParallelDocumentGeneratorError.noProvider
        }

        // Use preloaded templates
        let templates = preloadedData.dfTemplates

        // Generate documents in batches
        var allDocuments: [GeneratedDocument] = []

        for batchStart in stride(from: 0, to: dfDocumentTypes.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, dfDocumentTypes.count)
            let batchTypes = Array(dfDocumentTypes[batchStart ..< batchEnd])

            let batchDocuments = try await withThrowingTaskGroup(of: GeneratedDocument?.self) { group in
                for dfDocumentType in batchTypes {
                    group.addTask { @Sendable in
                        let provider = aiProvider
                        do {
                            let config = DFDocumentGenerationConfig(
                                dfDocumentType: dfDocumentType,
                                requirements: requirements,
                                template: templates[dfDocumentType],
                                systemPrompt: preloadedData.dfSystemPrompts[dfDocumentType],
                                profile: profile,
                                aiProvider: provider
                            )
                            return try await generateSingleDFDocument(config: config)
                        } catch {
                            // Log error but don't fail the entire batch
                            print("Error generating \(dfDocumentType): \(error)")
                            return nil
                        }
                    }
                }

                var documents: [GeneratedDocument] = []
                for try await document in group {
                    if let doc = document {
                        documents.append(doc)
                    }
                }
                return documents
            }

            allDocuments.append(contentsOf: batchDocuments)

            // Small delay between batches to avoid rate limiting
            if batchEnd < dfDocumentTypes.count {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }

        return allDocuments
    }

    // MARK: - Template Loading

    private func loadTemplatesParallel(for documentTypes: [DocumentType]) async -> [DocumentType: String] {
        await withTaskGroup(of: (DocumentType, String?).self) { group in
            for documentType in documentTypes {
                group.addTask {
                    // Check cache first
                    if let cached = await cache.getCachedTemplate(for: documentType) {
                        return (documentType, cached)
                    }

                    // Load from service
                    if let template = try? await templateService.loadTemplate(documentType) {
                        await cache.cacheTemplate(template, for: documentType)
                        return (documentType, template)
                    }

                    return (documentType, nil)
                }
            }

            var templates: [DocumentType: String] = [:]
            for await (documentType, template) in group {
                if let template {
                    templates[documentType] = template
                }
            }
            return templates
        }
    }

    private func loadDFTemplatesParallel(for dfDocumentTypes: [DFDocumentType]) async -> [DFDocumentType: DFTemplate] {
        await withTaskGroup(of: (DFDocumentType, DFTemplate?).self) { group in
            for dfDocumentType in dfDocumentTypes {
                group.addTask {
                    // Load from service (D&F templates are more complex, so we don't cache the full template)
                    if let template = try? await dfTemplateService.loadTemplate(dfDocumentType) {
                        return (dfDocumentType, template)
                    }
                    return (dfDocumentType, nil)
                }
            }

            var templates: [DFDocumentType: DFTemplate] = [:]
            for await (dfDocumentType, template) in group {
                if let template {
                    templates[dfDocumentType] = template
                }
            }
            return templates
        }
    }

    // MARK: - Single Document Generation

    private func generateSingleDocument(
        config: DocumentGenerationConfig
    ) async throws -> GeneratedDocument {
        let totalStartTime = Date()
        let cacheCheckStartTime = Date()
        var apiCallDuration: TimeInterval?
        var templateLoadDuration: TimeInterval = 0
        var spellCheckDuration: TimeInterval = 0
        // Prepare prompt
        let templateStartTime = Date()
        let prompt: String
        if let template = config.template {
            var processedTemplate = template
            if let profile = config.profile {
                for (key, value) in profile.templateVariables {
                    processedTemplate = processedTemplate.replacingOccurrences(of: "{{\(key)}}", with: value)
                }
            }
            prompt = AIDocumentGenerator.createTemplateBasedPrompt(
                for: config.documentType,
                requirements: config.requirements,
                template: processedTemplate,
                profile: config.profile
            )
        } else {
            prompt = AIDocumentGenerator.createPrompt(
                for: config.documentType,
                requirements: config.requirements,
                profile: config.profile
            )
        }
        templateLoadDuration = Date().timeIntervalSince(templateStartTime)

        // Use preloaded system prompt or generate if not available
        let finalSystemPrompt = config.systemPrompt ?? AIDocumentGenerator.getSystemPrompt(for: config.documentType)

        // Create messages
        let messages = [
            AIMessage.user(prompt),
        ]

        // Create request
        let request = AICompletionRequest(
            messages: messages,
            model: "claude-sonnet-4-20250514",
            maxTokens: 4096,
            systemPrompt: finalSystemPrompt
        )

        // Generate content
        let apiStartTime = Date()
        let result = try await config.aiProvider.complete(request)
        apiCallDuration = Date().timeIntervalSince(apiStartTime)

        let content = result.content

        // Spell check
        let spellCheckStartTime = Date()
        let correctedContent = await spellCheckService.checkAndCorrect(content)
        spellCheckDuration = Date().timeIntervalSince(spellCheckStartTime)

        // Cache the result
        await cache.cacheDocument(
            correctedContent,
            for: config.documentType,
            requirements: config.requirements,
            profile: config.profile
        )

        // Performance tracking removed for now
        let totalDuration = Date().timeIntervalSince(totalStartTime)
        print("[Performance] Generated \(config.documentType.rawValue) in \(totalDuration)s")

        return GeneratedDocument(
            title: "\(config.documentType.shortName) - \(Date().formatted(date: .abbreviated, time: .omitted))",
            documentType: config.documentType,
            content: correctedContent
        )
    }

    private func generateSingleDFDocument(
        config: DFDocumentGenerationConfig
    ) async throws -> GeneratedDocument {
        let totalStartTime = Date()
        let cacheCheckStartTime = Date()
        var apiCallDuration: TimeInterval?
        var templateLoadDuration: TimeInterval = 0
        var spellCheckDuration: TimeInterval = 0
        guard let template = config.template else {
            throw AIDocumentGeneratorError.noContent
        }

        // Process template
        let templateStartTime = Date()
        var processedTemplate = template.template
        if let profile = config.profile {
            for (key, value) in profile.templateVariables {
                processedTemplate = processedTemplate.replacingOccurrences(of: "{{\(key)}}", with: value)
            }
        }

        // Create prompt
        let prompt = AIDocumentGenerator.createDFPrompt(
            for: config.dfDocumentType,
            requirements: config.requirements,
            template: processedTemplate,
            quickReference: template.quickReferenceGuide,
            profile: config.profile
        )
        templateLoadDuration = Date().timeIntervalSince(templateStartTime)

        // Use preloaded system prompt or generate if not available
        let finalSystemPrompt = config.systemPrompt ?? AIDocumentGenerator.getDFSystemPrompt(for: config.dfDocumentType)

        // Create messages
        let messages = [
            AIMessage.user(prompt),
        ]

        // Create request
        let request = AICompletionRequest(
            messages: messages,
            model: "claude-sonnet-4-20250514",
            maxTokens: 4096,
            systemPrompt: finalSystemPrompt
        )

        // Generate content
        let apiStartTime = Date()
        let result = try await config.aiProvider.complete(request)
        apiCallDuration = Date().timeIntervalSince(apiStartTime)

        let content = result.content

        // Spell check
        let spellCheckStartTime = Date()
        let correctedContent = await spellCheckService.checkAndCorrect(content)
        spellCheckDuration = Date().timeIntervalSince(spellCheckStartTime)

        // Cache the result
        await cache.cacheDocument(
            correctedContent,
            for: config.dfDocumentType,
            requirements: config.requirements,
            profile: config.profile
        )

        // Performance tracking removed for now
        let totalDuration = Date().timeIntervalSince(totalStartTime)
        print("[Performance] Generated \(config.dfDocumentType.rawValue) D&F in \(totalDuration)s")

        return GeneratedDocument(
            title: "\(config.dfDocumentType.shortName) D&F - \(Date().formatted(date: .abbreviated, time: .omitted))",
            dfDocumentType: config.dfDocumentType,
            content: correctedContent
        )
    }
}

public enum ParallelDocumentGeneratorError: Error {
    case noProvider
}

// MARK: - Dependency Key

public struct ParallelDocumentGeneratorKey: DependencyKey {
    public nonisolated static let liveValue = ParallelDocumentGenerator()
    public nonisolated static let testValue = ParallelDocumentGenerator()
}

public extension DependencyValues {
    var parallelDocumentGenerator: ParallelDocumentGenerator {
        get { self[ParallelDocumentGeneratorKey.self] }
        set { self[ParallelDocumentGeneratorKey.self] = newValue }
    }
}
