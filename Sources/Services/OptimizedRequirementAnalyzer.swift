import AikoCompat
import AppCore
import ComposableArchitecture
import Foundation

/// Optimized RequirementAnalyzer with batching and enhanced caching
public struct OptimizedRequirementAnalyzer: Sendable {
    public var analyzeRequirements: @Sendable (String) async throws -> (response: String, recommendedDocuments: [DocumentType])
    public var analyzeDocumentContent: @Sendable (Data, String) async throws -> (response: String, recommendedDocuments: [DocumentType])
    public var enhancePrompt: @Sendable (String) async throws -> String
    public var batchAnalyzeRequirements: @Sendable ([String]) async throws -> [(response: String, recommendedDocuments: [DocumentType])]

    public init(
        analyzeRequirements: @escaping @Sendable (String) async throws -> (response: String, recommendedDocuments: [DocumentType]),
        analyzeDocumentContent: @escaping @Sendable (Data, String) async throws -> (response: String, recommendedDocuments: [DocumentType]),
        enhancePrompt: @escaping @Sendable (String) async throws -> String,
        batchAnalyzeRequirements: @escaping @Sendable ([String]) async throws -> [(response: String, recommendedDocuments: [DocumentType])]
    ) {
        self.analyzeRequirements = analyzeRequirements
        self.analyzeDocumentContent = analyzeDocumentContent
        self.enhancePrompt = enhancePrompt
        self.batchAnalyzeRequirements = batchAnalyzeRequirements
    }
}

// MARK: - API Request Batching

actor APIRequestBatcher {
    private var pendingRequests: [(String, CheckedContinuation<(response: String, recommendedDocuments: [DocumentType]), Error>)] = []
    private var batchTimer: Task<Void, Never>?
    private let batchSize = 5
    private let batchDelay: Duration = .milliseconds(100)

    func addRequest(_ requirements: String) async throws -> (response: String, recommendedDocuments: [DocumentType]) {
        try await withCheckedThrowingContinuation { continuation in
            pendingRequests.append((requirements, continuation))

            if pendingRequests.count >= batchSize {
                Task {
                    await processBatch()
                }
            } else if batchTimer == nil {
                batchTimer = Task {
                    try? await Task.sleep(for: batchDelay)
                    await processBatch()
                }
            }
        }
    }

    private func processBatch() async {
        guard !pendingRequests.isEmpty else { return }

        let batch = pendingRequests
        pendingRequests.removeAll()
        batchTimer = nil

        let requirements = batch.map(\.0)

        do {
            let results = try await batchAnalyze(requirements: requirements)

            for (index, result) in results.enumerated() where index < batch.count {
                batch[index].1.resume(returning: result)
            }
        } catch {
            // On error, fail all requests in the batch
            for request in batch {
                request.1.resume(throwing: error)
            }
        }
    }

    func batchAnalyze(requirements: [String]) async throws -> [(response: String, recommendedDocuments: [DocumentType])] {
        guard let aiProvider = await AIProviderFactory.defaultProvider() else {
            throw OptimizedRequirementAnalyzerError.noProvider
        }

        // Create a batch prompt that analyzes multiple requirements
        let batchPrompt = """
        Analyze the following \(requirements.count) acquisition requirements separately:

        \(requirements.enumerated().map { index, req in
            "### Requirement \(index + 1):\n\(req)\n"
        }.joined(separator: "\n"))

        For EACH requirement above, provide a comprehensive acquisition analysis with:
        1. REQUIREMENTS ANALYSIS
        2. REGULATORY COMPLIANCE
        3. ACQUISITION APPROACH
        4. MISSING INFORMATION
        5. RISK ASSESSMENT
        6. RECOMMENDATIONS

        Separate each analysis with "---NEXT---"
        """

        let messages = [
            AIMessage.user(batchPrompt),
        ]

        let request = AICompletionRequest(
            messages: messages,
            model: "claude-sonnet-4-20250514",
            maxTokens: 4096,
            systemPrompt: GovernmentAcquisitionPrompts.generateCompletePrompt(for: batchPrompt)
        )

        let result = try await aiProvider.complete(request)
        let content = result.content

        // Split responses
        let responses = content.components(separatedBy: "---NEXT---")

        return responses.enumerated().compactMap { index, response in
            guard index < requirements.count else { return nil }
            let recommendedTypes = OptimizedRequirementAnalyzer.parseRecommendations(from: response)
            return (response: response.trimmingCharacters(in: .whitespacesAndNewlines), recommendedDocuments: recommendedTypes)
        }
    }
}

// MARK: - Dependency Implementation

extension OptimizedRequirementAnalyzer: DependencyKey {
    public static var liveValue: OptimizedRequirementAnalyzer {
        let batcher = APIRequestBatcher()
        @Dependency(\.documentCacheService) var cacheService

        return OptimizedRequirementAnalyzer(
            analyzeRequirements: { requirements in
                // Check cache first
                if let cached = await cacheService.getCachedAnalysisResponse(requirements) {
                    return cached
                }

                // Use batcher for API calls
                let result = try await batcher.addRequest(requirements)

                // Cache the result
                try await cacheService.cacheAnalysisResponse(
                    requirements,
                    result.response,
                    result.recommendedDocuments
                )

                return result
            },
            analyzeDocumentContent: { documentData, fileName in
                // Create a cache key from file data
                let cacheKey = "\(fileName)_\(documentData.hashValue)"

                // Check cache first
                if let cached = await cacheService.getCachedAnalysisResponse(cacheKey) {
                    return cached
                }

                // Parse document content first
                let parser = DocumentParser()
                let documentContent: String = if fileName.lowercased().hasSuffix(".pdf") {
                    try await parser.parseDocument(documentData, type: .pdf)
                } else if fileName.lowercased().hasSuffix(".txt") || fileName.lowercased().hasSuffix(".docx") {
                    try await parser.parseDocument(documentData, type: .plainText)
                } else {
                    try await parser.parseImage(documentData)
                }

                // Use batcher for analysis
                let truncatedContent = String(documentContent.prefix(2000))
                let analysisRequirements = "Document: \(fileName)\nContent: \(truncatedContent)"

                let result = try await batcher.addRequest(analysisRequirements)

                // Cache the result
                try await cacheService.cacheAnalysisResponse(
                    cacheKey,
                    result.response,
                    result.recommendedDocuments
                )

                return result
            },
            enhancePrompt: { prompt in
                // Check cache for similar prompts
                let cacheKey = "enhance_\(prompt)"
                if let cached = await cacheService.getCachedAnalysisResponse(cacheKey) {
                    return cached.response
                }

                guard let aiProvider = await AIProviderFactory.defaultProvider() else {
                    throw OptimizedRequirementAnalyzerError.noProvider
                }

                let messages = [
                    AIMessage.user("""
                    Please enhance and improve the following acquisition requirements prompt to make it more specific, comprehensive, and actionable for generating government contract documents. Keep the enhanced version clear and concise:

                    Original prompt: \(prompt)

                    Enhanced prompt:
                    """),
                ]

                let request = AICompletionRequest(
                    messages: messages,
                    model: "claude-sonnet-4-20250514",
                    maxTokens: 500,
                    temperature: 0.3,
                    systemPrompt: "You are an expert at refining government acquisition requirements. Enhance prompts to be more specific about scope, deliverables, timeline, and technical requirements while maintaining clarity."
                )

                let result = try await aiProvider.complete(request)

                let enhanced = result.content.trimmingCharacters(in: .whitespacesAndNewlines)

                // Cache the enhancement
                try? await cacheService.cacheAnalysisResponse(cacheKey, enhanced, [])

                return enhanced
            },
            batchAnalyzeRequirements: { requirements in
                // Check cache for each requirement
                var cachedResults: [(Int, (response: String, recommendedDocuments: [DocumentType]))] = []
                var uncachedRequirements: [(Int, String)] = []

                for (index, req) in requirements.enumerated() {
                    if let cached = await cacheService.getCachedAnalysisResponse(req) {
                        cachedResults.append((index, cached))
                    } else {
                        uncachedRequirements.append((index, req))
                    }
                }

                // Process uncached requirements
                var apiResults: [(Int, (response: String, recommendedDocuments: [DocumentType]))] = []

                if !uncachedRequirements.isEmpty {
                    let requirementsToAnalyze = uncachedRequirements.map(\.1)
                    let results = try await batcher.batchAnalyze(requirements: requirementsToAnalyze)

                    for (i, result) in results.enumerated() where i < uncachedRequirements.count {
                        let originalIndex = uncachedRequirements[i].0
                        apiResults.append((originalIndex, result))

                        // Cache the result
                        try? await cacheService.cacheAnalysisResponse(
                            uncachedRequirements[i].1,
                            result.response,
                            result.recommendedDocuments
                        )
                    }
                }

                // Combine and sort results
                let allResults = (cachedResults + apiResults).sorted { $0.0 < $1.0 }
                return allResults.map(\.1)
            }
        )
    }

    public static var testValue: OptimizedRequirementAnalyzer {
        OptimizedRequirementAnalyzer(
            analyzeRequirements: RequirementAnalyzer.testValue.analyzeRequirements,
            analyzeDocumentContent: RequirementAnalyzer.testValue.analyzeDocumentContent,
            enhancePrompt: RequirementAnalyzer.testValue.enhancePrompt,
            batchAnalyzeRequirements: { requirements in
                requirements.map { req in
                    (response: "Batch analysis for: \(req)", recommendedDocuments: [.sow, .pws])
                }
            }
        )
    }

    static func parseRecommendations(from content: String) -> [DocumentType] {
        let lowercaseContent = content.lowercased()
        var recommendations: [DocumentType] = []

        // Parse recommendations section
        if let recommendationsRange = content.range(of: "RECOMMENDATIONS:", options: .caseInsensitive) {
            let recommendationsText = String(content[recommendationsRange.upperBound...])
            let lines = recommendationsText.components(separatedBy: .newlines)
            let firstLine = lines.first ?? ""

            // Extract document type abbreviations
            if firstLine.contains("SOW") || lowercaseContent.contains("statement of work") {
                recommendations.append(.sow)
            }
            if firstLine.contains("PWS") || lowercaseContent.contains("performance work") {
                recommendations.append(.pws)
            }
            if firstLine.contains("QASP") || lowercaseContent.contains("quality assurance") {
                recommendations.append(.qasp)
            }
            if firstLine.contains("Scaffold") || lowercaseContent.contains("acquisition strategy") {
                recommendations.append(.acquisitionPlan)
            }
            if firstLine.contains("IGCE") || lowercaseContent.contains("cost estimate") {
                recommendations.append(.costEstimate)
            }
        }

        // Fallback: Always recommend basic documents if none found
        if recommendations.isEmpty {
            recommendations = [.sow, .pws]
        }

        return recommendations
    }
}

public extension DependencyValues {
    var optimizedRequirementAnalyzer: OptimizedRequirementAnalyzer {
        get { self[OptimizedRequirementAnalyzer.self] }
        set { self[OptimizedRequirementAnalyzer.self] = newValue }
    }
}

public enum OptimizedRequirementAnalyzerError: Error {
    case noProvider
}

// MARK: - Migration Helper

public extension RequirementAnalyzer {
    /// Creates an optimized version of the requirement analyzer
    var optimized: OptimizedRequirementAnalyzer {
        @Dependency(\.optimizedRequirementAnalyzer) var analyzer
        return analyzer
    }
}
