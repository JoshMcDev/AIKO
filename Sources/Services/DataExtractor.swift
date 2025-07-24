import Foundation
import NaturalLanguage

// MARK: - Extracted Data Types

/// Structured data extracted from documents
public struct DataExtractorResult: Codable, Equatable {
    public let vendorName: String?
    public let vendorAddress: String?
    public let vendorPhone: String?
    public let vendorEmail: String?
    public let vendorUEI: String?
    public let vendorCAGE: String?
    public let quoteNumber: String?
    public let quoteDate: Date?
    public let validUntilDate: Date?
    public let totalPrice: Decimal?
    public let lineItems: [LineItem]
    public let paymentTerms: String?
    public let deliveryTerms: String?
    public let warrantyTerms: String?

    public init(
        vendorName: String? = nil,
        vendorAddress: String? = nil,
        vendorPhone: String? = nil,
        vendorEmail: String? = nil,
        vendorUEI: String? = nil,
        vendorCAGE: String? = nil,
        quoteNumber: String? = nil,
        quoteDate: Date? = nil,
        validUntilDate: Date? = nil,
        totalPrice: Decimal? = nil,
        lineItems: [LineItem] = [],
        paymentTerms: String? = nil,
        deliveryTerms: String? = nil,
        warrantyTerms: String? = nil
    ) {
        self.vendorName = vendorName
        self.vendorAddress = vendorAddress
        self.vendorPhone = vendorPhone
        self.vendorEmail = vendorEmail
        self.vendorUEI = vendorUEI
        self.vendorCAGE = vendorCAGE
        self.quoteNumber = quoteNumber
        self.quoteDate = quoteDate
        self.validUntilDate = validUntilDate
        self.totalPrice = totalPrice
        self.lineItems = lineItems
        self.paymentTerms = paymentTerms
        self.deliveryTerms = deliveryTerms
        self.warrantyTerms = warrantyTerms
    }
}

/// Line item in extracted data
public struct LineItem: Codable, Equatable {
    public let itemNumber: String?
    public let description: String
    public let quantity: Double
    public let unitPrice: Decimal
    public let totalPrice: Decimal

    public init(
        itemNumber: String? = nil,
        description: String,
        quantity: Double,
        unitPrice: Decimal,
        totalPrice: Decimal
    ) {
        self.itemNumber = itemNumber
        self.description = description
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = totalPrice
    }
}

/// Data extractor for parsing structured information from text
public final class DataExtractor {
    // MARK: - Regular Expressions

    private let emailRegex = try! NSRegularExpression(
        pattern: "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}",
        options: []
    )

    private let phoneRegex = try! NSRegularExpression(
        pattern: "\\b(?:\\+?1[-.]?)?\\(?([0-9]{3})\\)?[-.]?([0-9]{3})[-.]?([0-9]{4})\\b",
        options: []
    )

    private let priceRegex = try! NSRegularExpression(
        pattern: "\\$\\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\\.[0-9]{2})?)",
        options: []
    )

    private let dateRegex = try! NSRegularExpression(
        pattern: "\\b(0?[1-9]|1[0-2])[-/](0?[1-9]|[12][0-9]|3[01])[-/](\\d{2,4})\\b",
        options: []
    )

    private let ueiRegex = try! NSRegularExpression(
        pattern: "\\b[A-Z0-9]{12}\\b",
        options: []
    )

    private let cageRegex = try! NSRegularExpression(
        pattern: "\\b[A-Z0-9]{5}\\b",
        options: []
    )

    // MARK: - Extract Method

    /// Extract structured data from text
    public func extract(from text: String) async throws -> DataExtractorResult {
        // Use NLP for entity recognition
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text

        var vendorName: String?
        var vendorAddress: String?
        var extractedEmails: [String] = []
        var extractedPhones: [String] = []
        var extractedPrices: [Decimal] = []
        var extractedDates: [Date] = []

        // Extract organizations using NLP
        tagger.enumerateTags(in: text.startIndex ..< text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if tag == .organizationName {
                let organization = String(text[range])
                if vendorName == nil, organization.count > 2 {
                    vendorName = organization
                }
            }
            return true
        }

        // Extract emails
        let emailMatches = emailRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        extractedEmails = emailMatches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }

        // Extract phone numbers
        let phoneMatches = phoneRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        extractedPhones = phoneMatches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }

        // Extract prices
        let priceMatches = priceRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        extractedPrices = priceMatches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            let priceString = String(text[range]).replacingOccurrences(of: ",", with: "")
            return Decimal(string: priceString)
        }

        // Extract dates
        extractedDates = extractDates(from: text)

        // Extract UEI and CAGE codes
        let vendorUEI = extractUEI(from: text)
        let vendorCAGE = extractCAGE(from: text)

        // Look for quote number
        let quoteNumber = extractQuoteNumber(from: text)

        // Extract address if found near vendor name
        if vendorName != nil {
            vendorAddress = extractAddress(from: text, nearVendorName: vendorName)
        }

        // Extract line items
        let lineItems = extractLineItems(from: text, prices: extractedPrices)

        // Extract terms
        let paymentTerms = extractTerms(from: text, type: "payment")
        let deliveryTerms = extractTerms(from: text, type: "delivery")
        let warrantyTerms = extractTerms(from: text, type: "warranty")

        // Build extracted data
        return DataExtractorResult(
            vendorName: vendorName,
            vendorAddress: vendorAddress,
            vendorPhone: extractedPhones.first,
            vendorEmail: extractedEmails.first,
            vendorUEI: vendorUEI,
            vendorCAGE: vendorCAGE,
            quoteNumber: quoteNumber,
            quoteDate: extractedDates.first,
            validUntilDate: extractedDates.count > 1 ? extractedDates[1] : nil,
            totalPrice: extractedPrices.max(),
            lineItems: lineItems,
            paymentTerms: paymentTerms,
            deliveryTerms: deliveryTerms,
            warrantyTerms: warrantyTerms
        )
    }

    // MARK: - Extraction Helpers

    private func extractDates(from text: String) -> [Date] {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")

        let dateFormats = [
            "MM/dd/yyyy",
            "MM-dd-yyyy",
            "MM/dd/yy",
            "MM-dd-yy",
            "MMMM d, yyyy",
            "MMM d, yyyy",
        ]

        var dates: [Date] = []

        // Try regex matches first
        let dateMatches = dateRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in dateMatches {
            guard let range = Range(match.range, in: text) else { continue }
            let dateString = String(text[range])

            for format in dateFormats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: dateString) {
                    dates.append(date)
                    break
                }
            }
        }

        // Try other date formats
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        for i in 0 ..< words.count {
            let combined = words[max(0, i - 2) ... min(words.count - 1, i + 2)].joined(separator: " ")

            for format in dateFormats {
                dateFormatter.dateFormat = format
                if let date = dateFormatter.date(from: combined) {
                    dates.append(date)
                }
            }
        }

        return dates
    }

    private func extractQuoteNumber(from text: String) -> String? {
        let patterns = [
            "Quote\\s*#?\\s*:?\\s*([A-Z0-9-]+)",
            "Quotation\\s*#?\\s*:?\\s*([A-Z0-9-]+)",
            "RFQ\\s*#?\\s*:?\\s*([A-Z0-9-]+)",
            "Reference\\s*#?\\s*:?\\s*([A-Z0-9-]+)",
            "Proposal\\s*#?\\s*:?\\s*([A-Z0-9-]+)",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        return nil
    }

    private func extractUEI(from text: String) -> String? {
        let ueiPatterns = [
            "UEI\\s*:?\\s*([A-Z0-9]{12})",
            "Unique Entity ID\\s*:?\\s*([A-Z0-9]{12})",
            "SAM UEI\\s*:?\\s*([A-Z0-9]{12})",
        ]

        for pattern in ueiPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        // Fallback to generic UEI pattern
        let matches = ueiRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        if let match = matches.first,
           let range = Range(match.range, in: text) {
            let candidate = String(text[range])
            // Basic validation - UEI should not be all numbers
            if !candidate.allSatisfy(\.isNumber) {
                return candidate
            }
        }

        return nil
    }

    private func extractCAGE(from text: String) -> String? {
        let cagePatterns = [
            "CAGE\\s*(?:Code)?\\s*:?\\s*([A-Z0-9]{5})",
            "Commercial and Government Entity\\s*:?\\s*([A-Z0-9]{5})",
        ]

        for pattern in cagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }

        return nil
    }

    private func extractAddress(from text: String, nearVendorName: String?) -> String? {
        guard let vendorName = nearVendorName else { return nil }

        // Look for address patterns near vendor name
        let lines = text.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() where line.contains(vendorName) {
            // Check next few lines for address patterns
            var addressLines: [String] = []

            for i in 1 ... 3 where index + i < lines.count {
                let potentialAddressLine = lines[index + i].trimmingCharacters(in: .whitespaces)

                // Check for address patterns
                if potentialAddressLine.range(of: "\\d+.*(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Drive|Dr|Lane|Ln|Way|Court|Ct|Place|Pl)",
                                              options: .regularExpression) != nil ||
                    potentialAddressLine.range(of: "\\b[A-Z]{2}\\s+\\d{5}(?:-\\d{4})?\\b",
                                               options: .regularExpression) != nil ||
                    potentialAddressLine.range(of: "P\\.?O\\.?\\s*Box",
                                               options: [.regularExpression, .caseInsensitive]) != nil {
                    addressLines.append(potentialAddressLine)
                }
            }

            if !addressLines.isEmpty {
                return addressLines.joined(separator: ", ")
            }
        }

        return nil
    }

    private func extractLineItems(from text: String, prices: [Decimal]) -> [LineItem] {
        var lineItems: [LineItem] = []
        let lines = text.components(separatedBy: .newlines)

        // Look for table-like structures or price patterns
        for (_, line) in lines.enumerated() {
            // Skip if line is too short
            guard line.count > 10 else { continue }

            // Look for lines containing prices
            for price in prices {
                if line.contains(String(describing: price)) || line.contains("$\(price)") {
                    // Try to extract quantity
                    let quantityDecimal = extractQuantity(from: line) ?? Decimal(1)
                    let quantity = NSDecimalNumber(decimal: quantityDecimal).doubleValue

                    // Extract description
                    var description = line
                        .replacingOccurrences(of: "\\$[\\d,]+\\.?\\d*", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\\b\\d+\\s*(?:x|X|ea|EA|each|Each)\\b", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    // Clean up description
                    description = description
                        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .punctuationCharacters)

                    if !description.isEmpty, description.count > 3 {
                        let unitPrice = quantityDecimal > 0 ? price / quantityDecimal: price

                        lineItems.append(LineItem(
                            itemNumber: "\(lineItems.count + 1)",
                            description: description,
                            quantity: quantity,
                            unitPrice: unitPrice,
                            totalPrice: price
                        ))
                    }
                }
            }
        }

        return lineItems
    }

    private func extractQuantity(from line: String) -> Decimal? {
        let patterns = [
            "(?:Qty:?\\s*|Quantity:?\\s*)?([0-9]+(?:\\.[0-9]+)?)\\s*(?:x|X|ea|EA|each|Each)",
            "([0-9]+(?:\\.[0-9]+)?)\\s*(?:units?|Units?|pcs?|PCS?)",
            "\\b([0-9]+)\\s+@\\s*\\$",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let range = Range(match.range(at: 1), in: line) {
                return Decimal(string: String(line[range]))
            }
        }

        return nil
    }

    private func extractTerms(from text: String, type: String) -> String? {
        let patterns: [String]

        switch type {
        case "payment":
            patterns = [
                "Payment Terms?\\s*:?\\s*([^\\n]+)",
                "Terms?\\s*:?\\s*([^\\n]+)",
                "Net\\s*(\\d+)\\s*days?",
            ]
        case "delivery":
            patterns = [
                "Delivery Terms?\\s*:?\\s*([^\\n]+)",
                "Shipping Terms?\\s*:?\\s*([^\\n]+)",
                "FOB\\s*([^\\n]+)",
                "Delivery\\s*:?\\s*([^\\n]+)",
            ]
        case "warranty":
            patterns = [
                "Warranty\\s*:?\\s*([^\\n]+)",
                "Guarantee\\s*:?\\s*([^\\n]+)",
                "(\\d+)\\s*(?:year|month|day)s?\\s*warranty",
            ]
        default:
            return nil
        }

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let terms = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !terms.isEmpty {
                    return terms
                }
            }
        }

        return nil
    }
}
