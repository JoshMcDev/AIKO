@testable import AppCore
import ComposableArchitecture
import XCTest

/// Performance tests for critical user paths in AIKO-IOS
@MainActor
final class CriticalPathPerformanceTests: XCTestCase {
    // MARK: - Document Generation Critical Path

    func testDocumentGenerationE2EPerformance() async throws {
        let generationEngine = DocumentGenerationEngine()

        let requirements = DocumentRequirements(
            title: "Performance Test Document",
            type: .pws,
            description: "Testing document generation performance",
            objectives: ["Objective 1", "Objective 2", "Objective 3"],
            evaluationCriteria: ["Criteria 1", "Criteria 2"],
            researchScope: "Performance testing scope",
            includesFARClauses: true,
            selectedFARClauses: [
                DocumentFARClause(
                    id: "1",
                    clauseNumber: "52.212-4",
                    title: "Contract Terms and Conditions",
                    isRequired: true
                ),
            ],
            estimatedValue: 100_000,
            acquisitionMethod: .competitive
        )

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Document generation")

            Task {
                // Full document generation pipeline

                // 1. Validate requirements
                let validation = DocumentGenerationEngine.validateRequirements(requirements)
                XCTAssertTrue(validation.isValid)

                // 2. Generate outline
                let outline = DocumentGenerationEngine.generateOutline(for: requirements)
                XCTAssertFalse(outline.sections.isEmpty)

                // 3. Generate content (simulated)
                let content = await generateDocumentContent(from: outline, requirements: requirements)
                XCTAssertFalse(content.isEmpty)

                // 4. Apply FAR clauses
                let finalContent = await applyFARClauses(to: content, clauses: requirements.selectedFARClauses)

                // 5. Create final document
                let document = GeneratedDocument(
                    title: requirements.title,
                    documentType: requirements.type,
                    content: finalContent
                )

                XCTAssertEqual(document.documentType, requirements.type)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }

    // MARK: - SAM.gov Lookup Critical Path

    func testSAMGovLookupPerformance() async throws {
        // Simulate SAM.gov lookup workflow
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "SAM lookup")

            Task {
                // 1. Parse search entries
                let searchEntries = [
                    "ABC Corporation",
                    "XYZ Industries LLC",
                    "123 Federal Contractors Inc",
                ]

                // 2. Concurrent lookups
                await withTaskGroup(of: SAMSearchResult.self) { group in
                    for entry in searchEntries {
                        group.addTask {
                            await self.performSAMSearch(for: entry)
                        }
                    }

                    var results: [SAMSearchResult] = []
                    for await result in group {
                        results.append(result)
                    }

                    // 3. Process results
                    let validResults = results.filter(\.isValid)
                    XCTAssertFalse(validResults.isEmpty)
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Acquisition Chat Interaction

    func testAcquisitionChatInteractionPerformance() async throws {
        let chatState = OptimizedChatState()
        var effectManager = EffectManager()

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Chat interaction")

            Task {
                // Simulate typical chat interaction

                // 1. User types message
                let userMessage = "I need to create a performance work statement for IT services"

                // 2. Process input
                let processedInput = RequirementsAnalyzer.generateRelevantName(from: userMessage)
                XCTAssertFalse(processedInput.isEmpty)

                // 3. Generate AI response (simulated)
                let aiResponse = await generateAIResponse(for: userMessage)

                // 4. Update state
                var newState = chatState
                newState.messages.append(
                    ChatMessage(
                        id: UUID(),
                        role: .user,
                        content: userMessage,
                        timestamp: Date()
                    )
                )
                newState.messages.append(
                    ChatMessage(
                        id: UUID(),
                        role: .assistant,
                        content: aiResponse,
                        timestamp: Date()
                    )
                )

                // 5. Check for document suggestions
                let suggestions = await generateDocumentSuggestions(from: aiResponse)
                newState.ui.suggestions = suggestions

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 3.0)
        }
    }

    // MARK: - Template Search and Load

    func testTemplateSearchAndLoadPerformance() async throws {
        let templateService = UnifiedTemplateService()

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Template operations")

            Task {
                // 1. Search templates
                let searchQuery = "performance work statement"
                let searchResults = try await templateService.searchTemplates(
                    query: searchQuery,
                    in: [.builtin, .userCreated]
                )

                // 2. Filter by compliance
                let farCompliantTemplates = try await templateService.filterTemplates(
                    searchResults,
                    by: .compliance(.farCompliant)
                )

                // 3. Load selected template
                if let selectedTemplate = farCompliantTemplates.first {
                    let fullTemplate = try await templateService.loadTemplate(selectedTemplate.id)
                    XCTAssertNotNil(fullTemplate)

                    // 4. Validate template
                    let validationResult = try await templateService.validateTemplate(fullTemplate)
                    XCTAssertTrue(validationResult.isValid)
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Document Sharing Workflow

    func testDocumentSharingWorkflowPerformance() async throws {
        var shareState = ShareFeature.State()

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Share workflow")

            Task {
                // 1. Select documents
                let documentIds = (0 ..< 10).map { _ in UUID() }
                shareState.mode = .multipleDocuments
                shareState.selectedDocumentIds = Set(documentIds)

                // 2. Prepare share items
                let shareItems = await prepareShareItems(for: Array(documentIds))
                shareState.shareItems = shareItems

                // 3. Generate share metadata
                let metadata = await generateShareMetadata(
                    for: shareItems,
                    mode: shareState.mode
                )

                // 4. Perform share (simulated)
                let shareResult = await performShare(items: shareItems, metadata: metadata)
                XCTAssertTrue(shareResult.success)

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 3.0)
        }
    }

    // MARK: - Biometric Authentication Flow

    func testBiometricAuthenticationPerformance() async throws {
        var authState = AuthenticationFeature.State(
            biometricType: .faceID
        )

        measure(metrics: [XCTClockMetric()]) {
            let expectation = self.expectation(description: "Authentication")

            Task {
                // 1. Check biometric availability
                let biometricType = await checkBiometricAvailability()
                authState.biometricType = biometricType

                // 2. Prepare authentication
                authState.isAuthenticating = true

                // 3. Perform authentication (simulated)
                let authResult = await performBiometricAuth(type: biometricType)

                // 4. Update state
                if authResult.success {
                    authState.isAuthenticated = true
                    authState.lastAuthenticationDate = Date()
                } else {
                    authState.authenticationError = authResult.error
                }
                authState.isAuthenticating = false

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 2.0)
        }
    }

    // MARK: - App Launch Performance

    func testColdAppLaunchPerformance() async throws {
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            let expectation = self.expectation(description: "Cold launch")

            Task {
                // Simulate cold app launch

                // 1. Initialize core services
                let cacheService = UnifiedDocumentCacheService()
                let templateService = UnifiedTemplateService()
                let complianceManager = FARComplianceManager()

                // 2. Load user preferences
                let preferences = await loadUserPreferences()

                // 3. Check authentication
                let needsAuth = preferences["requiresAuthentication"] as? Bool ?? true

                // 4. Initialize app state
                let appState = OptimizedAppFeature.State()

                // 5. Preload critical data
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        _ = try? await templateService.fetchTemplates(from: [.builtin])
                    }

                    group.addTask {
                        _ = await cacheService.statistics()
                    }

                    if needsAuth {
                        group.addTask {
                            _ = await checkBiometricAvailability()
                        }
                    }
                }

                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Helper Methods

    private func generateDocumentContent(
        from outline: DocumentOutline,
        requirements: DocumentRequirements
    ) async -> String {
        // Simulate content generation
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        var content = "# \(requirements.title)\n\n"

        for section in outline.sections {
            content += "## \(section.title)\n\n"
            for subsection in section.subsections {
                content += "### \(subsection)\n\n"
                content += "Content for \(subsection)...\n\n"
            }
        }

        return content
    }

    private func applyFARClauses(
        to content: String,
        clauses: [DocumentFARClause]
    ) async -> String {
        // Simulate FAR clause application
        var finalContent = content

        finalContent += "\n## Applicable FAR Clauses\n\n"
        for clause in clauses {
            finalContent += "### \(clause.clauseNumber) - \(clause.title)\n\n"
            finalContent += "This contract incorporates the provisions of FAR \(clause.clauseNumber).\n\n"
        }

        return finalContent
    }

    private func performSAMSearch(for entity: String) async -> SAMSearchResult {
        // Simulate SAM.gov search
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        return SAMSearchResult(
            entityName: entity,
            uei: "UEI\(Int.random(in: 100_000 ... 999_999))",
            cageCode: "CAGE\(Int.random(in: 10000 ... 99999))",
            registrationStatus: "Active",
            expirationDate: Date().addingTimeInterval(365 * 24 * 60 * 60),
            isValid: true
        )
    }

    private func generateAIResponse(for _: String) async -> String {
        // Simulate AI response generation
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        return """
        I'll help you create a performance work statement for IT services. \
        A PWS should focus on outcomes and performance standards rather than \
        prescriptive requirements. Let me guide you through the key sections...
        """
    }

    private func generateDocumentSuggestions(from _: String) async -> [String] {
        // Simulate suggestion generation
        [
            "Create Performance Work Statement",
            "Add Quality Assurance Surveillance Plan",
            "Include Performance Metrics",
        ]
    }

    private func prepareShareItems(for documentIds: [UUID]) async -> [Any] {
        // Simulate share item preparation
        try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        return documentIds.map { "Document-\($0.uuidString)" }
    }

    private func generateShareMetadata(for items: [Any], mode: ShareMode) async -> ShareMetadata {
        ShareMetadata(
            itemCount: items.count,
            shareMode: mode,
            timestamp: Date(),
            format: "PDF"
        )
    }

    private func performShare(items _: [Any], metadata _: ShareMetadata) async -> ShareResult {
        // Simulate share operation
        try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
        return ShareResult(success: true, error: nil)
    }

    private func checkBiometricAvailability() async -> BiometricType {
        // Simulate biometric check
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
        return .faceID
    }

    private func performBiometricAuth(type _: BiometricType) async -> AuthResult {
        // Simulate authentication
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        return AuthResult(success: true, error: nil)
    }

    private func loadUserPreferences() async -> [String: Any] {
        // Simulate preference loading
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        return [
            "requiresAuthentication": true,
            "defaultDocumentType": "pws",
            "enableAdaptiveCaching": true,
        ]
    }
}

// MARK: - Supporting Types

private struct SAMSearchResult {
    let entityName: String
    let uei: String
    let cageCode: String
    let registrationStatus: String
    let expirationDate: Date
    let isValid: Bool
}

private struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    enum MessageRole {
        case user
        case assistant
    }
}

private struct ShareMetadata {
    let itemCount: Int
    let shareMode: ShareMode
    let timestamp: Date
    let format: String
}

private struct ShareResult {
    let success: Bool
    let error: String?
}

private struct AuthResult {
    let success: Bool
    let error: String?
}
