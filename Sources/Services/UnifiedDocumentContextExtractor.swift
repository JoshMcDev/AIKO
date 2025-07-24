import AppCore
import Foundation
import UniformTypeIdentifiers
import Vision

// MARK: - Unified Document Context Extractor

/// Unified service that orchestrates all document extraction components
/// for the Adaptive Prompting Engine
public final class UnifiedDocumentContextExtractor: @unchecked Sendable {
    /// Shared instance for non-MainActor contexts
    @MainActor
    public static let shared = UnifiedDocumentContextExtractor()

    /// Non-MainActor shared instance for dependency injection
    public static let sharedNonMainActor = UnifiedDocumentContextExtractor(
        documentParser: DocumentParserEnhanced(),
        contextExtractor: DocumentContextExtractorEnhanced.shared,
        adaptiveExtractor: AdaptiveDataExtractor.shared
    )

    private let documentParser: DocumentParserEnhanced
    private let contextExtractor: DocumentContextExtractorEnhanced
    private let adaptiveExtractor: AdaptiveDataExtractor

    @MainActor
    public init() {
        documentParser = DocumentParserEnhanced()
        contextExtractor = DocumentContextExtractorEnhanced()
        adaptiveExtractor = AdaptiveDataExtractor()
    }

    public init(
        documentParser: DocumentParserEnhanced,
        contextExtractor: DocumentContextExtractorEnhanced,
        adaptiveExtractor: AdaptiveDataExtractor
    ) {
        self.documentParser = documentParser
        self.contextExtractor = contextExtractor
        self.adaptiveExtractor = adaptiveExtractor
    }

    /// Main entry point for document context extraction
    /// Handles everything from raw document data to structured context
    public func extractComprehensiveContext(
        from documentData: [(data: Data, type: UniformTypeIdentifiers.UTType)],
        withHints: [String: Any]? = nil
    ) async throws -> ComprehensiveDocumentContext {
        // Step 1: Parse all documents (OCR if needed)
        var parsedDocuments: [ParsedDocument] = []

        for (data, type) in documentData {
            do {
                let docType = mapUTTypeToDocumentType(type)
                let parsed = try await documentParser.parse(data, type: docType)
                parsedDocuments.append(parsed)
            } catch {
                print("Warning: Failed to parse document: \(error)")
                // Continue with other documents
            }
        }

        guard !parsedDocuments.isEmpty else {
            throw DocumentExtractionError.noDocumentsParsed
        }

        // Step 2: Extract context using both standard and adaptive extraction
        let extractedContext = try await contextExtractor.extract(from: parsedDocuments)

        // Step 3: Apply adaptive learning for better pattern recognition
        var adaptiveResults: [AdaptiveExtractionResult] = []

        for document in parsedDocuments {
            let adaptiveResult = try await adaptiveExtractor.extractAdaptively(
                from: document,
                withHints: withHints
            )
            adaptiveResults.append(adaptiveResult)
        }

        // Step 4: Merge and consolidate all extraction results
        let consolidatedContext = consolidateResults(
            standardContext: extractedContext,
            adaptiveResults: adaptiveResults,
            parsedDocuments: parsedDocuments
        )

        // Step 5: Calculate overall confidence
        let confidence = calculateOverallConfidence(
            context: consolidatedContext,
            adaptiveResults: adaptiveResults
        )

        return ComprehensiveDocumentContext(
            extractedContext: consolidatedContext,
            parsedDocuments: parsedDocuments,
            adaptiveResults: adaptiveResults,
            confidence: confidence,
            extractionDate: Date()
        )
    }

    /// Extract comprehensive context directly from OCR results
    /// Optimized pathway for Phase 4.2 enhanced OCR integration
    public func extractComprehensiveContext(
        from ocrResults: [OCRResult],
        pageImageData: [Data] = [],
        withHints: [String: Any]? = nil
    ) async throws -> ComprehensiveDocumentContext {
        guard !ocrResults.isEmpty else {
            throw DocumentExtractionError.noDocumentsParsed
        }

        // Step 1: Convert OCR results to ParsedDocument format for compatibility
        var parsedDocuments: [ParsedDocument] = []

        for (index, ocrResult) in ocrResults.enumerated() {
            let parsedDoc = ParsedDocument(
                id: UUID(),
                sourceType: .ocr,
                extractedText: ocrResult.fullText,
                metadata: ParsedDocumentMetadata(
                    fileName: "OCR Document \(index + 1)",
                    fileSize: ocrResult.fullText.data(using: .utf8)?.count ?? 0,
                    pageCount: 1
                ),
                extractedData: convertOCRToExtractedDataForParser(ocrResult),
                confidence: ocrResult.confidence
            )
            parsedDocuments.append(parsedDoc)
        }

        // Step 2: Extract context using enhanced OCR data
        let extractedContext = try await extractContextFromOCRResults(ocrResults)

        // Step 3: Apply adaptive learning if we have image data
        var adaptiveResults: [AdaptiveExtractionResult] = []

        if !pageImageData.isEmpty {
            for (index, _) in pageImageData.enumerated() {
                guard index < parsedDocuments.count else { break }

                let adaptiveResult = try await adaptiveExtractor.extractAdaptively(
                    from: parsedDocuments[index],
                    withHints: withHints
                )
                adaptiveResults.append(adaptiveResult)
            }
        }

        // Step 4: Merge OCR-based context with adaptive results
        let consolidatedContext = consolidateOCRResults(
            ocrContext: extractedContext,
            adaptiveResults: adaptiveResults,
            ocrResults: ocrResults
        )

        // Step 5: Calculate confidence based on OCR and adaptive results
        let confidence = calculateOCRBasedConfidence(
            context: consolidatedContext,
            ocrResults: ocrResults,
            adaptiveResults: adaptiveResults
        )

        return ComprehensiveDocumentContext(
            extractedContext: consolidatedContext,
            parsedDocuments: parsedDocuments,
            adaptiveResults: adaptiveResults,
            confidence: confidence,
            extractionDate: Date()
        )
    }

    // MARK: - Helper Methods

    private func mapUTTypeToDocumentType(_ type: UniformTypeIdentifiers.UTType) -> ParsedDocumentType {
        switch type {
        case .pdf:
            .pdf
        case .rtf:
            .rtf
        case .plainText:
            .text
        case .png:
            .png
        case .jpeg:
            .jpeg
        case .heic:
            .heic
        default:
            if type.conforms(to: .image) {
                .unknown // Will use OCR
            } else if isWordDocument(type) {
                .word
            } else {
                .unknown
            }
        }
    }

    private func isWordDocument(_ type: UniformTypeIdentifiers.UTType) -> Bool {
        let wordTypes = [
            "com.microsoft.word.doc",
            "com.microsoft.word.docx",
            "org.openxmlformats.wordprocessingml.document",
        ]
        return wordTypes.contains(type.identifier)
    }

    private func consolidateResults(
        standardContext: ExtractedContext,
        adaptiveResults: [AdaptiveExtractionResult],
        parsedDocuments _: [ParsedDocument]
    ) -> ExtractedContext {
        // Start with standard extraction results
        var consolidatedVendorInfo = standardContext.vendorInfo
        var consolidatedPricing = standardContext.pricing
        var consolidatedDates = standardContext.dates
        var consolidatedTechnicalDetails = standardContext.technicalDetails
        var consolidatedSpecialTerms = standardContext.specialTerms
        var consolidatedConfidence = standardContext.confidence

        // Enhance with adaptive extraction results
        for result in adaptiveResults {
            // Update vendor info with higher confidence values
            if let vendorInfo = extractVendorInfoFromAdaptive(result) {
                consolidatedVendorInfo = mergeVendorInfo(
                    existing: consolidatedVendorInfo,
                    new: vendorInfo,
                    confidence: result.confidence
                )
            }

            // Update pricing with more detailed line items
            if let pricing = extractPricingFromAdaptive(result) {
                consolidatedPricing = mergePricing(
                    existing: consolidatedPricing,
                    new: pricing,
                    confidence: result.confidence
                )
            }

            // Update dates with better pattern recognition
            if let dates = extractDatesFromAdaptive(result) {
                consolidatedDates = mergeDates(
                    existing: consolidatedDates,
                    new: dates,
                    confidence: result.confidence
                )
            }

            // Add technical details from adaptive extraction
            let technicalDetails = extractTechnicalDetailsFromAdaptive(result)
            consolidatedTechnicalDetails.append(contentsOf: technicalDetails)

            // Add special terms from adaptive extraction
            let specialTerms = extractSpecialTermsFromAdaptive(result)
            consolidatedSpecialTerms.append(contentsOf: specialTerms)

            // Update confidence scores
            updateConfidenceScores(
                &consolidatedConfidence,
                from: result
            )
        }

        // Remove duplicates and clean up
        consolidatedTechnicalDetails = Array(Set(consolidatedTechnicalDetails))
            .filter { !$0.isEmpty && $0.count > 10 }
        consolidatedSpecialTerms = Array(Set(consolidatedSpecialTerms))

        return ExtractedContext(
            vendorInfo: consolidatedVendorInfo,
            pricing: consolidatedPricing,
            technicalDetails: consolidatedTechnicalDetails,
            dates: consolidatedDates,
            specialTerms: consolidatedSpecialTerms,
            confidence: consolidatedConfidence
        )
    }

    private func extractVendorInfoFromAdaptive(_ result: AdaptiveExtractionResult) -> APEVendorInfo? {
        var vendorInfo = APEVendorInfo()
        var hasData = false

        for object in result.valueObjects {
            switch object.fieldName.lowercased() {
            case "vendor", "vendor_name", "company":
                vendorInfo.name = object.value
                hasData = true
            case "vendor_email", "email":
                vendorInfo.email = object.value
                hasData = true
            case "vendor_phone", "phone":
                vendorInfo.phone = object.value
                hasData = true
            case "vendor_address", "address":
                vendorInfo.address = object.value
                hasData = true
            case "uei", "vendor_uei":
                vendorInfo.uei = object.value
                hasData = true
            case "cage", "vendor_cage":
                vendorInfo.cage = object.value
                hasData = true
            default:
                break
            }
        }

        return hasData ? vendorInfo : nil
    }

    private func extractPricingFromAdaptive(_ result: AdaptiveExtractionResult) -> PricingInfo? {
        var totalPrice: Decimal?
        var lineItems: [APELineItem] = []

        for object in result.valueObjects where object.dataType == .currency {
            if object.fieldName.lowercased().contains("total") {
                totalPrice = Decimal(string: object.value.replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: ""))
            } else {
                // Might be a line item price
                if let price = Decimal(string: object.value.replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: ",", with: "")) {
                    lineItems.append(APELineItem(
                        description: object.fieldName,
                        quantity: 1,
                        unitPrice: price,
                        totalPrice: price
                    ))
                }
            }
        }

        if totalPrice != nil || !lineItems.isEmpty {
            return PricingInfo(totalPrice: totalPrice, unitPrices: lineItems)
        }

        return nil
    }

    private func extractDatesFromAdaptive(_ result: AdaptiveExtractionResult) -> ExtractedDates? {
        var dates = ExtractedDates()
        var hasData = false

        for object in result.valueObjects where object.dataType == .date {
            if let date = parseDate(object.value) {
                switch object.fieldName.lowercased() {
                case "quote_date", "date":
                    dates.quoteDate = date
                    hasData = true
                case "valid_until", "expiration":
                    dates.validUntil = date
                    hasData = true
                case "delivery_date", "due_date":
                    dates.deliveryDate = date
                    hasData = true
                default:
                    break
                }
            }
        }

        return hasData ? dates: nil
    }

    private func extractTechnicalDetailsFromAdaptive(_ result: AdaptiveExtractionResult) -> [String] {
        result.valueObjects
            .filter { $0.fieldName.lowercased().contains("technical") ||
                $0.fieldName.lowercased().contains("specification") ||
                $0.fieldName.lowercased().contains("feature")
            }
            .map(\.value)
            .filter { $0.count > 20 }
    }

    private func extractSpecialTermsFromAdaptive(_ result: AdaptiveExtractionResult) -> [String] {
        result.valueObjects
            .filter { $0.fieldName.lowercased().contains("term") ||
                $0.fieldName.lowercased().contains("condition") ||
                $0.fieldName.lowercased().contains("requirement")
            }
            .map(\.value)
    }

    private func mergeVendorInfo(
        existing: APEVendorInfo?,
        new: APEVendorInfo,
        confidence: Double
    ) -> APEVendorInfo {
        guard let existing else { return new }
        guard confidence > 0.8 else { return existing } // Only merge if high confidence

        return APEVendorInfo(
            name: new.name ?? existing.name,
            uei: new.uei ?? existing.uei,
            cage: new.cage ?? existing.cage,
            email: new.email ?? existing.email,
            phone: new.phone ?? existing.phone,
            address: new.address ?? existing.address
        )
    }

    private func mergePricing(
        existing: PricingInfo?,
        new: PricingInfo,
        confidence: Double
    ) -> PricingInfo {
        guard let existing else { return new }
        guard confidence > 0.7 else { return existing }

        return PricingInfo(
            totalPrice: new.totalPrice ?? existing.totalPrice,
            unitPrices: existing.unitPrices + new.unitPrices,
            currency: new.currency
        )
    }

    private func mergeDates(
        existing: ExtractedDates?,
        new: ExtractedDates,
        confidence: Double
    ) -> ExtractedDates {
        guard let existing else { return new }
        guard confidence > 0.7 else { return existing }

        return ExtractedDates(
            quoteDate: new.quoteDate ?? existing.quoteDate,
            validUntil: new.validUntil ?? existing.validUntil,
            deliveryDate: new.deliveryDate ?? existing.deliveryDate,
            performancePeriod: new.performancePeriod ?? existing.performancePeriod
        )
    }

    private func updateConfidenceScores(
        _ confidence: inout [RequirementField: Float],
        from result: AdaptiveExtractionResult
    ) {
        // Map adaptive fields to requirement fields
        let fieldMappings: [(pattern: String, field: RequirementField)] = [
            ("vendor", .vendorName),
            ("uei", .vendorUEI),
            ("cage", .vendorCAGE),
            ("price", .estimatedValue),
            ("date", .requiredDate),
            ("technical", .technicalSpecs),
            ("special", .specialConditions),
        ]

        for object in result.valueObjects {
            for (pattern, field) in fieldMappings where object.fieldName.lowercased().contains(pattern) {
                    let currentConfidence = confidence[field] ?? 0
                    confidence[field] = max(currentConfidence, Float(object.confidence))
                }
            }
        }
    }

    private func calculateOverallConfidence(
        context: ExtractedContext,
        adaptiveResults: [AdaptiveExtractionResult]
    ) -> Double {
        var scores: [Double] = []

        // Add confidence from standard extraction
        scores.append(contentsOf: context.confidence.values.map { Double($0) })

        // Add confidence from adaptive extraction
        scores.append(contentsOf: adaptiveResults.map(\.confidence))

        // Calculate weighted average
        guard !scores.isEmpty else { return 0.0 }
        let average = scores.reduce(0.0, +) / Double(scores.count)

        // Boost confidence if we have multiple extraction methods agreeing
        let agreementBonus = adaptiveResults.isEmpty ? 0.0 : 0.1

        return min(average + agreementBonus, 1.0)
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatters = [
            ISO8601DateFormatter(),
            DateFormatter.mmddyyyy,
            DateFormatter.yyyymmdd,
            DateFormatter.mmmddyyyy,
        ]

        // Try ISO8601 first
        if let iso = formatters.first as? ISO8601DateFormatter,
           let date = iso.date(from: dateString) {
            return date
        }

        // Try other formatters
        for formatter in formatters.dropFirst() {
            if let formatter = formatter as? DateFormatter,
               let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    // MARK: - OCR-Based Extraction Methods

    private func convertOCRToExtractedDataForParser(_ ocrResult: OCRResult) -> ExtractedData {
        // Convert OCRResult to DocumentParserEnhanced's ExtractedData format
        var entities: [ExtractedEntity] = []
        let relationships: [ExtractedRelationship] = []
        var tables: [ExtractedTable] = []

        // Convert form fields to entities
        for field in ocrResult.recognizedFields {
            let entityType: ExtractedEntity.EntityType = switch field.fieldType {
            case .email: .email
            case .phone: .phone
            case .address: .address
            case .currency, .number: .price
            case .date: .date
            default: .unknown
            }

            entities.append(ExtractedEntity(
                type: entityType,
                value: field.value,
                confidence: field.confidence,
                location: ExtractedLocation(
                    pageNumber: 1,
                    boundingBox: field.boundingBox
                )
            ))
        }

        // Convert extracted metadata to entities
        for currency in ocrResult.extractedMetadata.currencies {
            entities.append(ExtractedEntity(
                type: .price,
                value: currency.originalText,
                confidence: currency.confidence
            ))
        }

        for date in ocrResult.extractedMetadata.dates {
            entities.append(ExtractedEntity(
                type: .date,
                value: date.originalText,
                confidence: date.confidence
            ))
        }

        for email in ocrResult.extractedMetadata.emailAddresses {
            entities.append(ExtractedEntity(
                type: .email,
                value: email,
                confidence: 0.9
            ))
        }

        for phone in ocrResult.extractedMetadata.phoneNumbers {
            entities.append(ExtractedEntity(
                type: .phone,
                value: phone,
                confidence: 0.9
            ))
        }

        // Convert tables from document structure
        for table in ocrResult.documentStructure.tables {
            let headers = table.rows.first?.map(\.content) ?? []
            let dataRows = Array(table.rows.dropFirst()).map { row in
                row.map(\.content)
            }

            tables.append(ExtractedTable(
                headers: headers,
                rows: dataRows,
                confidence: table.confidence
            ))
        }

        return ExtractedData(
            entities: entities,
            relationships: relationships,
            tables: tables,
            summary: ocrResult.fullText.count > 500 ? String(ocrResult.fullText.prefix(500)) + "..." : nil
        )
    }

    private func convertOCRToExtractedData(_ ocrResult: OCRResult) -> [String: Any] {
        var extractedData: [String: Any] = [:]

        // Add form fields
        var formFields: [[String: Any]] = []
        for field in ocrResult.recognizedFields {
            formFields.append([
                "label": field.label,
                "value": field.value,
                "confidence": field.confidence,
                "type": field.fieldType.rawValue,
                "bounds": [
                    "x": field.boundingBox.origin.x,
                    "y": field.boundingBox.origin.y,
                    "width": field.boundingBox.size.width,
                    "height": field.boundingBox.size.height,
                ],
            ])
        }
        extractedData["form_fields"] = formFields

        // Add document structure
        extractedData["layout_type"] = ocrResult.documentStructure.layout.rawValue
        extractedData["paragraph_count"] = ocrResult.documentStructure.paragraphs.count
        extractedData["table_count"] = ocrResult.documentStructure.tables.count
        extractedData["list_count"] = ocrResult.documentStructure.lists.count
        extractedData["header_count"] = ocrResult.documentStructure.headers.count

        // Add extracted metadata
        extractedData["dates"] = ocrResult.extractedMetadata.dates.map { date in
            [
                "date": date.date.timeIntervalSince1970,
                "original_text": date.originalText,
                "confidence": date.confidence,
                "context": date.context ?? "",
            ]
        }

        extractedData["currencies"] = ocrResult.extractedMetadata.currencies.map { currency in
            [
                "amount": currency.amount.description,
                "currency": currency.currency,
                "original_text": currency.originalText,
                "confidence": currency.confidence,
            ]
        }

        extractedData["phone_numbers"] = ocrResult.extractedMetadata.phoneNumbers
        extractedData["email_addresses"] = ocrResult.extractedMetadata.emailAddresses
        extractedData["urls"] = ocrResult.extractedMetadata.urls

        return extractedData
    }

    private func extractContextFromOCRResults(_ ocrResults: [OCRResult]) async throws -> ExtractedContext {
        // Use the existing helper functions from DocumentScannerFeature but make them more sophisticated
        let vendorInfo = extractEnhancedVendorInfoFromOCR(ocrResults)
        let pricing = extractEnhancedPricingFromOCR(ocrResults)
        let technicalDetails = extractEnhancedTechnicalDetailsFromOCR(ocrResults)
        let dates = extractEnhancedDatesFromOCR(ocrResults)
        let specialTerms = extractEnhancedSpecialTermsFromOCR(ocrResults)
        let confidence = calculateEnhancedConfidenceFromOCR(ocrResults)

        return ExtractedContext(
            vendorInfo: vendorInfo,
            pricing: pricing,
            technicalDetails: technicalDetails,
            dates: dates,
            specialTerms: specialTerms,
            confidence: confidence
        )
    }

    private func consolidateOCRResults(
        ocrContext: ExtractedContext,
        adaptiveResults: [AdaptiveExtractionResult],
        ocrResults _: [OCRResult]
    ) -> ExtractedContext {
        // Start with OCR-based context
        var consolidatedVendorInfo = ocrContext.vendorInfo
        var consolidatedPricing = ocrContext.pricing
        var consolidatedDates = ocrContext.dates
        var consolidatedTechnicalDetails = ocrContext.technicalDetails
        var consolidatedSpecialTerms = ocrContext.specialTerms
        var consolidatedConfidence = ocrContext.confidence

        // For now, skip adaptive enhancement to get build working
        // TODO: Implement proper adaptive enhancement integration
        for result in adaptiveResults {
            // Simple enhancement - just add confidence if available
            if Float(result.confidence) > consolidatedConfidence[.vendorName] ?? 0 {
                consolidatedConfidence[.vendorName] = Float(result.confidence)
            }
        }

        // Remove duplicates
        consolidatedTechnicalDetails = Array(Set(consolidatedTechnicalDetails))
        consolidatedSpecialTerms = Array(Set(consolidatedSpecialTerms))

        return ExtractedContext(
            vendorInfo: consolidatedVendorInfo,
            pricing: consolidatedPricing,
            technicalDetails: consolidatedTechnicalDetails,
            dates: consolidatedDates,
            specialTerms: consolidatedSpecialTerms,
            confidence: consolidatedConfidence
        )
    }

    private func calculateOCRBasedConfidence(
        context: ExtractedContext,
        ocrResults: [OCRResult],
        adaptiveResults: [AdaptiveExtractionResult]
    ) -> Double {
        var scores: [Double] = []

        // Add OCR confidence scores
        scores.append(contentsOf: ocrResults.map(\.confidence))

        // Add context extraction confidence
        scores.append(contentsOf: context.confidence.values.map { Double($0) })

        // Add adaptive extraction confidence
        scores.append(contentsOf: adaptiveResults.map(\.confidence))

        guard !scores.isEmpty else { return 0.0 }
        let average = scores.reduce(0.0, +) / Double(scores.count)

        // Boost confidence if we have multiple high-quality sources
        let qualityBonus = (ocrResults.count > 1 && !adaptiveResults.isEmpty) ? 0.15 : 0.05

        return min(average + qualityBonus, 1.0)
    }

    // Enhanced extraction methods that leverage the structured OCR data

    private func extractEnhancedVendorInfoFromOCR(_ ocrResults: [OCRResult]) -> APEVendorInfo? {
        var vendorInfo = APEVendorInfo()
        var hasData = false

        for result in ocrResults {
            // Check form fields with higher precision
            for field in result.recognizedFields where field.confidence > 0.7 {
                switch field.label.lowercased() {
                case let label where label.contains("vendor") || label.contains("company") || label.contains("supplier"):
                    if field.fieldType == .text, !field.value.isEmpty {
                        vendorInfo.name = field.value
                        hasData = true
                    }
                case let label where label.contains("email"):
                    if field.fieldType == .email {
                        vendorInfo.email = field.value
                        hasData = true
                    }
                case let label where label.contains("phone"):
                    if field.fieldType == .phone {
                        vendorInfo.phone = field.value
                        hasData = true
                    }
                case let label where label.contains("address"):
                    if field.fieldType == .address {
                        vendorInfo.address = field.value
                        hasData = true
                    }
                case let label where label.contains("uei"):
                    vendorInfo.uei = field.value
                    hasData = true
                case let label where label.contains("cage"):
                    vendorInfo.cage = field.value
                    hasData = true
                default:
                    break
                }
            }

            // Check metadata with pattern matching
            for address in result.extractedMetadata.addresses where address.confidence > 0.8 {
                if vendorInfo.address == nil {
                    vendorInfo.address = address.fullAddress
                    hasData = true
                }
            }

            for email in result.extractedMetadata.emailAddresses where vendorInfo.email == nil {
                vendorInfo.email = email
                hasData = true
            }

            for phone in result.extractedMetadata.phoneNumbers where vendorInfo.phone == nil {
                vendorInfo.phone = phone
                hasData = true
            }
        }

        return hasData ? vendorInfo : nil
    }

    private func extractEnhancedPricingFromOCR(_ ocrResults: [OCRResult]) -> PricingInfo? {
        var totalPrice: Decimal?
        var lineItems: [APELineItem] = []

        for result in ocrResults {
            // Check form fields for pricing with higher confidence threshold
            for field in result.recognizedFields where field.confidence > 0.8 {
                if field.fieldType == .currency {
                    let cleanValue = field.value.replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                        .trimmingCharacters(in: .whitespaces)

                    if let price = Decimal(string: cleanValue) {
                        if field.label.lowercased().contains("total") ||
                            field.label.lowercased().contains("amount") {
                            totalPrice = price
                        } else {
                            lineItems.append(APELineItem(
                                description: field.label,
                                quantity: 1,
                                unitPrice: price,
                                totalPrice: price
                            ))
                        }
                    }
                }
            }

            // Process currency metadata with context analysis
            for currency in result.extractedMetadata.currencies where currency.confidence > 0.9 {
                if totalPrice == nil {
                    // Look for "total" context in surrounding text
                    let fullText = result.fullText.lowercased()
                    let currencyIndex = fullText.range(of: currency.originalText.lowercased())

                    if let index = currencyIndex {
                        let startIndex = max(fullText.startIndex,
                                             fullText.index(index.lowerBound, offsetBy: -50, limitedBy: fullText.startIndex) ?? fullText.startIndex)
                        let endIndex = min(fullText.endIndex,
                                           fullText.index(index.upperBound, offsetBy: 50, limitedBy: fullText.endIndex) ?? fullText.endIndex)
                        let surroundingRange = startIndex ..< endIndex
                        let context = String(fullText[surroundingRange])

                        if context.contains("total") || context.contains("amount due") {
                            totalPrice = currency.amount
                        } else {
                            lineItems.append(APELineItem(
                                description: "Item",
                                quantity: 1,
                                unitPrice: currency.amount,
                                totalPrice: currency.amount
                            ))
                        }
                    }
                }
            }
        }

        if totalPrice != nil || !lineItems.isEmpty {
            return PricingInfo(totalPrice: totalPrice, unitPrices: lineItems)
        }

        return nil
    }

    private func extractEnhancedTechnicalDetailsFromOCR(_ ocrResults: [OCRResult]) -> [String] {
        var technicalDetails: [String] = []

        for result in ocrResults {
            // Extract from form fields
            for field in result.recognizedFields where field.confidence > 0.7 {
                let label = field.label.lowercased()
                if label.contains("spec") || label.contains("technical") ||
                    label.contains("feature") || label.contains("requirement") {
                    if field.value.count > 20 {
                        technicalDetails.append(field.value)
                    }
                }
            }

            // Extract from document structure
            for paragraph in result.documentStructure.paragraphs where paragraph.confidence > 0.8 {
                let text = paragraph.text.lowercased()
                if text.contains("specification") || text.contains("technical") ||
                    text.contains("requirements") || text.contains("performance") {
                    if paragraph.text.count > 50 {
                        technicalDetails.append(paragraph.text)
                    }
                }
            }

            // Extract from lists that might contain technical specs
            for list in result.documentStructure.lists {
                for item in list.items where item.confidence > 0.8 {
                    let text = item.text.lowercased()
                    if text.contains("spec") || text.contains("feature") || text.contains("requirement") {
                        technicalDetails.append(item.text)
                    }
                }
            }
        }

        return Array(Set(technicalDetails))
    }

    private func extractEnhancedDatesFromOCR(_ ocrResults: [OCRResult]) -> ExtractedDates? {
        var dates = ExtractedDates()
        var hasData = false

        for result in ocrResults {
            // Check form fields for dates
            for field in result.recognizedFields where field.confidence > 0.8 {
                if field.fieldType == .date {
                    if let date = parseAdvancedDate(field.value) {
                        let label = field.label.lowercased()
                        if label.contains("quote") || label.contains("date") {
                            dates.quoteDate = date
                            hasData = true
                        } else if label.contains("valid") || label.contains("expir") {
                            dates.validUntil = date
                            hasData = true
                        } else if label.contains("delivery") || label.contains("due") {
                            dates.deliveryDate = date
                            hasData = true
                        }
                    }
                }
            }

            // Check extracted metadata dates with context
            for extractedDate in result.extractedMetadata.dates where extractedDate.confidence > 0.8 {
                if let context = extractedDate.context?.lowercased() {
                    if context.contains("quote"), dates.quoteDate == nil {
                        dates.quoteDate = extractedDate.date
                        hasData = true
                    } else if context.contains("delivery"), dates.deliveryDate == nil {
                        dates.deliveryDate = extractedDate.date
                        hasData = true
                    } else if context.contains("valid"), dates.validUntil == nil {
                        dates.validUntil = extractedDate.date
                        hasData = true
                    }
                } else {
                    // Assign to first available slot
                    if dates.quoteDate == nil {
                        dates.quoteDate = extractedDate.date
                        hasData = true
                    } else if dates.deliveryDate == nil {
                        dates.deliveryDate = extractedDate.date
                        hasData = true
                    }
                }
            }
        }

        return hasData ? dates : nil
    }

    private func extractEnhancedSpecialTermsFromOCR(_ ocrResults: [OCRResult]) -> [String] {
        var specialTerms: [String] = []

        for result in ocrResults {
            // Extract from form fields
            for field in result.recognizedFields where field.confidence > 0.7 {
                let label = field.label.lowercased()
                if label.contains("term") || label.contains("condition") ||
                    label.contains("requirement") || label.contains("clause") {
                    if field.value.count > 10 {
                        specialTerms.append(field.value)
                    }
                }
            }

            // Extract from lists that contain terms
            for list in result.documentStructure.lists {
                for item in list.items where item.confidence > 0.8 {
                    let text = item.text.lowercased()
                    if text.contains("term") || text.contains("condition") ||
                        text.contains("shall") || text.contains("must") {
                        specialTerms.append(item.text)
                    }
                }
            }
        }

        return Array(Set(specialTerms))
    }

    private func calculateEnhancedConfidenceFromOCR(_ ocrResults: [OCRResult]) -> [RequirementField: Float] {
        var confidence: [RequirementField: Float] = [:]

        let overallConfidence = ocrResults.isEmpty ? 0.0 :
            ocrResults.map(\.confidence).reduce(0, +) / Double(ocrResults.count)

        // Calculate field-specific confidence based on detection
        var fieldConfidences: [RequirementField: [Double]] = [:]

        for result in ocrResults {
            for field in result.recognizedFields {
                let label = field.label.lowercased()
                if label.contains("vendor") {
                    fieldConfidences[.vendorName, default: []].append(field.confidence)
                }
                if label.contains("price") || label.contains("cost") {
                    fieldConfidences[.estimatedValue, default: []].append(field.confidence)
                }
                if label.contains("date") {
                    fieldConfidences[.requiredDate, default: []].append(field.confidence)
                }
                if label.contains("technical") || label.contains("spec") {
                    fieldConfidences[.technicalSpecs, default: []].append(field.confidence)
                }
            }
        }

        // Calculate averages for detected fields
        for (field, confidences) in fieldConfidences {
            confidence[field] = Float(confidences.reduce(0, +) / Double(confidences.count))
        }

        // Fill in missing fields with overall confidence
        let allFields: [RequirementField] = [.vendorName, .vendorUEI, .vendorCAGE, .estimatedValue, .requiredDate, .technicalSpecs, .specialConditions]
        for field in allFields where confidence[field] == nil {
            confidence[field] = Float(overallConfidence * 0.8) // Slightly lower for undetected fields
        }

        return confidence
    }

    private func parseAdvancedDate(_ dateString: String) -> Date? {
        let formatters = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "yyyy-MM-dd",
            "MMMM dd, yyyy",
            "MMM dd, yyyy",
            "dd MMMM yyyy",
            "dd MMM yyyy",
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

// MARK: - Supporting Types

public struct ComprehensiveDocumentContext: Sendable {
    public let extractedContext: ExtractedContext
    public let parsedDocuments: [ParsedDocument]
    public let adaptiveResults: [AdaptiveExtractionResult]
    public let confidence: Double
    public let extractionDate: Date

    /// Check if we have sufficient context to proceed
    public var hasSufficientContext: Bool {
        confidence > 0.6 && !extractedContext.isEmpty
    }

    /// Get a summary of what was extracted
    public var summary: String {
        var parts: [String] = []

        if let vendor = extractedContext.vendorInfo?.name {
            parts.append("Vendor: \(vendor)")
        }

        if let price = extractedContext.pricing?.totalPrice {
            parts.append("Price: $\(price)")
        }

        if let date = extractedContext.dates?.deliveryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("Delivery: \(formatter.string(from: date))")
        }

        parts.append("Technical specs: \(extractedContext.technicalDetails.count)")
        parts.append("Confidence: \(Int(confidence * 100))%")

        return parts.joined(separator: " | ")
    }
}

extension ExtractedContext {
    var isEmpty: Bool {
        vendorInfo == nil &&
            pricing == nil &&
            technicalDetails.isEmpty &&
            dates == nil &&
            specialTerms.isEmpty
    }
}

public enum DocumentExtractionError: LocalizedError {
    case noDocumentsParsed
    case insufficientContext
    case extractionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noDocumentsParsed:
            "No documents could be parsed successfully"
        case .insufficientContext:
            "Insufficient context extracted from documents"
        case let .extractionFailed(reason):
            "Document extraction failed: \(reason)"
        }
    }
}

// DateFormatter extensions are already defined in DocumentContextExtractorEnhanced.swift
