@testable import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class UnifiedTemplateServiceTests: XCTestCase {
    var service: UnifiedTemplateService?

    private var serviceUnwrapped: UnifiedTemplateService {
        guard let service else { fatalError("service not initialized") }
        return service
    }

    override func setUp() async throws {
        try await super.setUp()
        service = UnifiedTemplateService()
    }

    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }

    // MARK: - Template Discovery Tests

    func testFetchTemplatesFromAllSources() async throws {
        let templates = try await serviceUnwrapped.fetchTemplates(
            from: [.builtin, .userCreated, .community, .organization]
        )

        XCTAssertFalse(templates.isEmpty)

        // Verify templates from different sources
        let sources = Set(templates.map(\.source))
        XCTAssertTrue(sources.contains(.builtin))

        // Verify template properties
        for template in templates {
            XCTAssertFalse(template.id.uuidString.isEmpty)
            XCTAssertFalse(template.metadata.name.isEmpty)
            XCTAssertNotNil(template.metadata.category)
            XCTAssertGreaterThan(template.metadata.version, 0)
        }
    }

    func testFetchTemplatesFromSpecificSource() async throws {
        let builtinTemplates = try await serviceUnwrapped.fetchTemplates(from: [.builtin])

        XCTAssertFalse(builtinTemplates.isEmpty)
        XCTAssertTrue(builtinTemplates.allSatisfy { $0.source == .builtin })
    }

    func testSearchTemplates() async throws {
        let searchQuery = "performance"
        let results = try await serviceUnwrapped.searchTemplates(
            query: searchQuery,
            in: [.builtin, .userCreated]
        )

        // Verify search results
        for template in results {
            let metadata = template.metadata
            let matchesName = metadata.name.lowercased().contains(searchQuery.lowercased())
            let matchesDescription = metadata.description.lowercased().contains(searchQuery.lowercased())
            let matchesTags = metadata.tags.contains { $0.lowercased().contains(searchQuery.lowercased()) }

            XCTAssertTrue(matchesName || matchesDescription || matchesTags,
                          "Template should match search query")
        }
    }

    func testFilterTemplatesByCategory() async throws {
        let templates = try await serviceUnwrapped.fetchTemplates(from: [.builtin])
        let filtered = try await serviceUnwrapped.filterTemplates(
            templates,
            by: .category(.contracts)
        )

        XCTAssertTrue(filtered.allSatisfy { $0.metadata.category == .contracts })
    }

    func testFilterTemplatesByCompliance() async throws {
        let templates = try await serviceUnwrapped.fetchTemplates(from: [.builtin])
        let filtered = try await serviceUnwrapped.filterTemplates(
            templates,
            by: .compliance(.farCompliant)
        )

        XCTAssertTrue(filtered.allSatisfy { template in
            template.metadata.complianceInfo?.contains { $0 == .farCompliant } ?? false
        })
    }

    // MARK: - Template Management Tests

    func testSaveUserTemplate() async throws {
        let customTemplate = DocumentTemplate(
            id: UUID(),
            source: .userCreated,
            metadata: UnifiedTemplateMetadata(
                name: "Custom Test Template",
                description: "A test template",
                category: .statements,
                tags: ["test", "custom"],
                author: "Test User",
                createdDate: Date(),
                lastModifiedDate: Date(),
                version: 1.0,
                isActive: true,
                complianceInfo: [.farCompliant],
                customProperties: ["testKey": "testValue"]
            ),
            structure: DocumentStructure(
                sections: [
                    DocumentSection(
                        id: UUID(),
                        title: "Test Section",
                        content: "Test content",
                        order: 1,
                        isRequired: true,
                        subsections: []
                    ),
                ],
                requiredFields: ["field1"],
                optionalFields: ["field2"]
            ),
            style: DocumentStyle(
                fontFamily: "System",
                fontSize: 12,
                lineSpacing: 1.5,
                margins: DocumentMargins(top: 1, bottom: 1, left: 1, right: 1),
                headerStyle: nil,
                footerStyle: nil
            )
        )

        try await serviceUnwrapped.saveTemplate(customTemplate)

        // Verify it was saved
        let userTemplates = try await serviceUnwrapped.fetchTemplates(from: [.userCreated])
        XCTAssertTrue(userTemplates.contains { $0.id == customTemplate.id })
    }

    func testDeleteTemplate() async throws {
        // First save a template
        let template = createTestTemplate()
        try await serviceUnwrapped.saveTemplate(template)

        // Delete it
        try await serviceUnwrapped.deleteTemplate(id: template.id)

        // Verify it's gone
        let templates = try await serviceUnwrapped.fetchTemplates(from: [.userCreated])
        XCTAssertFalse(templates.contains { $0.id == template.id })
    }

    func testDuplicateTemplate() async throws {
        let originalTemplate = createTestTemplate()

        let duplicated = try await serviceUnwrapped.duplicateTemplate(originalTemplate)

        XCTAssertNotEqual(duplicated.id, originalTemplate.id)
        XCTAssertEqual(duplicated.metadata.name, "\(originalTemplate.metadata.name) (Copy)")
        XCTAssertEqual(duplicated.structure, originalTemplate.structure)
        XCTAssertEqual(duplicated.style, originalTemplate.style)
    }

    // MARK: - Template Validation Tests

    func testValidateTemplate() async throws {
        let validTemplate = createTestTemplate()
        let validationResult = try await serviceUnwrapped.validateTemplate(validTemplate)

        XCTAssertTrue(validationResult.isValid)
        XCTAssertTrue(validationResult.errors.isEmpty)
    }

    func testValidateInvalidTemplate() async throws {
        var invalidTemplate = createTestTemplate()
        // Make template invalid by removing required sections
        invalidTemplate.structure.sections = []

        let validationResult = try await serviceUnwrapped.validateTemplate(invalidTemplate)

        XCTAssertFalse(validationResult.isValid)
        XCTAssertFalse(validationResult.errors.isEmpty)
    }

    // MARK: - Template Export/Import Tests

    func testExportTemplate() async throws {
        let template = createTestTemplate()

        let exportData = try await serviceUnwrapped.exportTemplate(
            template,
            format: .json
        )

        XCTAssertFalse(exportData.isEmpty)

        // Verify it's valid JSON
        let jsonObject = try JSONSerialization.jsonObject(with: exportData)
        XCTAssertNotNil(jsonObject)
    }

    func testImportTemplate() async throws {
        let template = createTestTemplate()
        let exportData = try await serviceUnwrapped.exportTemplate(template, format: .json)

        let importedTemplate = try await serviceUnwrapped.importTemplate(
            from: exportData,
            format: .json
        )

        XCTAssertEqual(importedTemplate.metadata.name, template.metadata.name)
        XCTAssertEqual(importedTemplate.structure.sections.count, template.structure.sections.count)
    }

    // MARK: - Batch Operations Tests

    func testBatchImportTemplates() async throws {
        let templates = [
            createTestTemplate(name: "Template 1"),
            createTestTemplate(name: "Template 2"),
            createTestTemplate(name: "Template 3"),
        ]

        var exportedData: [Data] = []
        for template in templates {
            let data = try await serviceUnwrapped.exportTemplate(template, format: .json)
            exportedData.append(data)
        }

        let results = await serviceUnwrapped.batchImportTemplates(
            from: exportedData,
            format: .json
        )

        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { result in
            if case .success = result { return true }
            return false
        })
    }

    // MARK: - Performance Tests

    func testFetchLargeNumberOfTemplates() async throws {
        let measure = XCTMeasureOptions()
        measure.iterationCount = 3

        self.measure(options: measure) {
            let expectation = self.expectation(description: "Fetch templates")

            Task {
                _ = try await serviceUnwrapped.fetchTemplates(from: TemplateSource.allCases)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 5.0)
        }
    }

    // MARK: - Helper Methods

    private func createTestTemplate(name: String = "Test Template") -> DocumentTemplate {
        DocumentTemplate(
            id: UUID(),
            source: .userCreated,
            metadata: UnifiedTemplateMetadata(
                name: name,
                description: "Test template description",
                category: .contracts,
                tags: ["test"],
                author: "Test Author",
                createdDate: Date(),
                lastModifiedDate: Date(),
                version: 1.0,
                isActive: true,
                complianceInfo: [.farCompliant],
                customProperties: [:]
            ),
            structure: DocumentStructure(
                sections: [
                    DocumentSection(
                        id: UUID(),
                        title: "Section 1",
                        content: "Content 1",
                        order: 1,
                        isRequired: true,
                        subsections: []
                    ),
                ],
                requiredFields: [],
                optionalFields: []
            ),
            style: DocumentStyle(
                fontFamily: "System",
                fontSize: 12,
                lineSpacing: 1.5,
                margins: DocumentMargins(top: 1, bottom: 1, left: 1, right: 1),
                headerStyle: nil,
                footerStyle: nil
            )
        )
    }
}

// MARK: - TemplateCategory Tests

final class TemplateCategoryTests: XCTestCase {
    func testAllCategoriesHaveValidRawValues() {
        let categories: [TemplateCategory] = [
            .contracts, .statements, .solicitations, .reports,
            .analysis, .planning, .compliance, .other,
        ]

        for category in categories {
            XCTAssertFalse(category.rawValue.isEmpty)
        }
    }
}

// MARK: - ComplianceType Tests

final class ComplianceTypeTests: XCTestCase {
    func testComplianceTypeEquality() {
        XCTAssertEqual(ComplianceType.farCompliant, ComplianceType.farCompliant)
        XCTAssertEqual(ComplianceType.dfarCompliant, ComplianceType.dfarCompliant)
        XCTAssertNotEqual(ComplianceType.farCompliant, ComplianceType.dfarCompliant)
    }
}
