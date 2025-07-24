import AppCore
import Foundation
import NaturalLanguage

// MARK: - Document Context Extractor

public final class DocumentContextExtractor: @unchecked Sendable {
    private let entityRecognizer = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    private let currencyRecognizer = NLTagger(tagSchemes: [.lexicalClass])

    public init() {}

    public func extract(from documents: [ParsedDocument]) async throws -> ExtractedContext {
        var vendorInfo: APEVendorInfo?
        var pricing: PricingInfo?
        var technicalDetails: [String] = []
        var dates: ExtractedDates?
        var specialTerms: [String] = []
        var confidence: [RequirementField: Float] = [:]

        for document in documents {
            // Extract vendor information
            if let extractedVendor = extractVendorInfo(from: document) {
                vendorInfo = extractedVendor
                confidence[.vendorName] = 0.9
                if extractedVendor.uei != nil {
                    confidence[.vendorUEI] = 0.95
                }
            }

            // Extract pricing
            if let extractedPricing = extractPricing(from: document) {
                pricing = extractedPricing
                confidence[.estimatedValue] = 0.85
            }

            // Extract technical details
            let extractedTechnical = extractTechnicalDetails(from: document)
            technicalDetails.append(contentsOf: extractedTechnical)
            if !extractedTechnical.isEmpty {
                confidence[.technicalSpecs] = 0.8
            }

            // Extract dates
            if let extractedDates = extractDates(from: document) {
                dates = extractedDates
                if extractedDates.deliveryDate != nil {
                    confidence[.requiredDate] = 0.85
                }
            }

            // Extract special terms
            let extractedTerms = extractSpecialTerms(from: document)
            specialTerms.append(contentsOf: extractedTerms)
            if !extractedTerms.isEmpty {
                confidence[.specialConditions] = 0.75
            }
        }

        return ExtractedContext(
            vendorInfo: vendorInfo,
            pricing: pricing,
            technicalDetails: Array(Set(technicalDetails)), // Remove duplicates
            dates: dates,
            specialTerms: Array(Set(specialTerms)),
            confidence: confidence
        )
    }

    // MARK: - Private Extraction Methods

    private func extractVendorInfo(from document: ParsedDocument) -> APEVendorInfo? {
        var vendorInfo = APEVendorInfo()

        // Extract from structured entities
        for entity in document.extractedData.entities {
            switch entity.type {
            case .vendor:
                vendorInfo.name = entity.value
            case .email:
                vendorInfo.email = entity.value
            case .phone:
                vendorInfo.phone = entity.value
            case .address:
                vendorInfo.address = entity.value
            default:
                break
            }
        }

        // Also check for UEI/CAGE in text
        if let ueiMatch = findPattern(#"(?:UEI|SAM UEI)[\s:#]+([A-Z0-9]{12})"#, in: document.extractedText) {
            vendorInfo.uei = ueiMatch
        }

        if let cageMatch = findPattern(#"(?:CAGE|CAGE Code)[\s:#]+([A-Z0-9]{5})"#, in: document.extractedText) {
            vendorInfo.cage = cageMatch
        }

        // Return nil if no vendor info found
        if vendorInfo.name == nil, vendorInfo.email == nil, vendorInfo.phone == nil {
            return nil
        }

        return vendorInfo
    }

    private func extractPricing(from document: ParsedDocument) -> PricingInfo? {
        var totalPrice: Decimal?
        var lineItems: [APELineItem] = []

        // Extract total price from entities
        for entity in document.extractedData.entities where entity.type == .price {
            // Remove currency symbols and convert to Decimal
            let cleanPrice = entity.value
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: ",", with: "")

            if let price = Decimal(string: cleanPrice) {
                totalPrice = price
                break
            }
        }

        // If no price in entities, try to extract from text
        if totalPrice == nil {
            let pricePatterns = [
                #"(?:Total|Grand Total|Total Price|Total Cost)[\s:]+\$?([\d,]+\.?\d*)"#,
                #"\$?([\d,]+\.?\d*)[\s]+(?:Total|total)"#,
            ]

            for pattern in pricePatterns {
                if let priceMatch = findPattern(pattern, in: document.extractedText) {
                    let cleanPrice = priceMatch.replacingOccurrences(of: ",", with: "")
                    if let price = Decimal(string: cleanPrice) {
                        totalPrice = price
                        break
                    }
                }
            }
        }

        // Try extracting line items from text
        let lineItemPattern = #"(.+?)\s+(?:Qty|QTY|Quantity)[\s:]+(\d+)\s+.+?\$?([\d,]+\.?\d*)"#
        if let regex = try? NSRegularExpression(pattern: lineItemPattern, options: []) {
            let matches = regex.matches(in: document.extractedText, options: [], range: NSRange(document.extractedText.startIndex..., in: document.extractedText))

            for match in matches.prefix(10) { // Limit to 10 line items
                if let descRange = Range(match.range(at: 1), in: document.extractedText),
                   let qtyRange = Range(match.range(at: 2), in: document.extractedText),
                   let priceRange = Range(match.range(at: 3), in: document.extractedText) {
                    let description = String(document.extractedText[descRange]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    let quantityStr = String(document.extractedText[qtyRange])
                    let priceStr = String(document.extractedText[priceRange]).replacingOccurrences(of: ",", with: "")

                    if let quantity = Int(quantityStr),
                       let unitPrice = Decimal(string: priceStr) {
                        lineItems.append(APELineItem(
                            id: UUID(),
                            description: description,
                            quantity: quantity,
                            unitPrice: unitPrice,
                            totalPrice: unitPrice * Decimal(quantity)
                        ))
                    }
                }
            }
        }

        if totalPrice != nil || !lineItems.isEmpty {
            return PricingInfo(
                totalPrice: totalPrice,
                unitPrices: lineItems,
                currency: "USD"
            )
        }

        return nil
    }

    private func extractTechnicalDetails(from document: ParsedDocument) -> [String] {
        let text = document.extractedText
        var details: [String] = []

        // Look for technical specifications
        let techPatterns = [
            #"(?:Technical Requirements|Specifications|Specs)[\s:]+(.+?)(?:\n\n|$)"#,
            #"(?:Performance Requirements)[\s:]+(.+?)(?:\n\n|$)"#,
            #"(?:Standards|Compliance)[\s:]+(.+?)(?:\n\n|$)"#,
        ]

        for pattern in techPatterns {
            if let match = findPattern(pattern, in: text) {
                let cleaned = match.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    details.append(cleaned)
                }
            }
        }

        // Extract bullet points that might be technical specs
        let bulletPattern = #"[•·-]\s*(.+?)(?:\n|$)"#
        if let regex = try? NSRegularExpression(pattern: bulletPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))

            for match in matches.prefix(20) { // Limit to first 20 bullets
                if let range = Range(match.range(at: 1), in: text) {
                    let bullet = String(text[range]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if bullet.count > 10, bullet.count < 200 { // Reasonable length for tech spec
                        details.append(bullet)
                    }
                }
            }
        }

        return details
    }

    private func extractDates(from document: ParsedDocument) -> ExtractedDates? {
        let text = document.extractedText
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")

        var quoteDate: Date?
        var validUntil: Date?
        var deliveryDate: Date?

        // Common date formats
        let dateFormats = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "MMM dd, yyyy",
            "MMMM dd, yyyy",
            "yyyy-MM-dd",
        ]

        // Look for specific date contexts
        let datePatterns = [
            ("Quote Date", #"(?:Quote Date|Date of Quote|Quotation Date)[\s:]+(.+?)(?:\n|$)"#),
            ("Valid Until", #"(?:Valid Until|Valid Through|Expires|Expiration)[\s:]+(.+?)(?:\n|$)"#),
            ("Delivery", #"(?:Delivery Date|Delivery|Required by|Due Date)[\s:]+(.+?)(?:\n|$)"#),
        ]

        for (dateType, pattern) in datePatterns {
            if let match = findPattern(pattern, in: text) {
                let dateString = match.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                for format in dateFormats {
                    dateFormatter.dateFormat = format
                    if let date = dateFormatter.date(from: dateString) {
                        switch dateType {
                        case "Quote Date": quoteDate = date
                        case "Valid Until": validUntil = date
                        case "Delivery": deliveryDate = date
                        default: break
                        }
                        break
                    }
                }
            }
        }

        if quoteDate != nil || validUntil != nil || deliveryDate != nil {
            return ExtractedDates(
                quoteDate: quoteDate,
                validUntil: validUntil,
                deliveryDate: deliveryDate,
                performancePeriod: nil
            )
        }

        return nil
    }

    private func extractSpecialTerms(from document: ParsedDocument) -> [String] {
        let text = document.extractedText
        var terms: [String] = []

        // Look for special conditions, terms, notes
        let termPatterns = [
            #"(?:Special Conditions|Terms and Conditions|Notes)[\s:]+(.+?)(?:\n\n|$)"#,
            #"(?:Important|Note|Notice)[\s:]+(.+?)(?:\n|$)"#,
            #"(?:Warranty|Guarantee)[\s:]+(.+?)(?:\n|$)"#,
        ]

        for pattern in termPatterns {
            if let match = findPattern(pattern, in: text) {
                let cleaned = match.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !cleaned.isEmpty, cleaned.count < 500 { // Reasonable length
                    terms.append(cleaned)
                }
            }
        }

        return terms
    }

    // MARK: - Helper Methods

    private func findPattern(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        // Return the first capture group if it exists, otherwise the whole match
        let captureRange = match.numberOfRanges > 1 ? match.range(at: 1): match.range
        guard let swiftRange = Range(captureRange, in: text) else {
            return nil
        }

        return String(text[swiftRange])
    }
}
