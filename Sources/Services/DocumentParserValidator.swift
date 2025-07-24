import AppCore
import Foundation
import UniformTypeIdentifiers

/// Validates documents and extracted data for the document parser
public final class DocumentParserValidator {
    // MARK: - Constants

    private static let maxFileSizeMB = 100
    private static let maxFileSize = maxFileSizeMB * 1024 * 1024
    private static let minTextLength = 10
    private static let maxTextLength = 5_000_000 // 5 million characters

    // Supported document types
    fileprivate static let supportedTypes: Set<String> = [
        UniformTypeIdentifiers.UTType.pdf.identifier,
        UniformTypeIdentifiers.UTType.rtf.identifier,
        UniformTypeIdentifiers.UTType.plainText.identifier,
        UniformTypeIdentifiers.UTType.png.identifier,
        UniformTypeIdentifiers.UTType.jpeg.identifier,
        UniformTypeIdentifiers.UTType.tiff.identifier,
        UniformTypeIdentifiers.UTType.heic.identifier,
        "com.microsoft.word.doc",
        "com.microsoft.word.docx",
        "org.openxmlformats.wordprocessingml.document",
        "com.microsoft.word.wordml",
    ]

    // MARK: - Public Methods

    /// Validates document data before parsing
    public func validateDocument(_ data: Data, type: UniformTypeIdentifiers.UTType) throws {
        // Check file size
        guard data.count <= Self.maxFileSize else {
            throw DocumentParserValidationError.fileTooLarge(
                sizeMB: data.count / (1024 * 1024),
                maxSizeMB: Self.maxFileSizeMB
            )
        }

        // Check if empty
        guard !data.isEmpty else {
            throw DocumentParserValidationError.emptyDocument
        }

        // Check supported type
        guard isSupportedType(type) else {
            throw DocumentParserValidationError.unsupportedDocumentType(type.identifier)
        }

        // Type-specific validation
        try validateDocumentStructure(data, type: type)
    }

    /// Validates document with expected type
    public func validate(_ data: Data, expectedType: DocumentValidationType) async -> DocumentValidationResult {
        do {
            // Map validation type to UniformTypeIdentifiers.UTType for compatibility
            let utType: UniformTypeIdentifiers.UTType = switch expectedType {
            case .pdf:
                .pdf
            case .word:
                UniformTypeIdentifiers.UTType(filenameExtension: "docx") ?? .data
            case .plainText:
                .plainText
            case .rtf:
                .rtf
            case .image:
                .image
            case .excel:
                UniformTypeIdentifiers.UTType(filenameExtension: "xlsx") ?? .data
            case .unknown:
                .data
            }

            try validateDocument(data, type: utType)
            return DocumentValidationResult(isValid: true, errors: [])
        } catch {
            return DocumentValidationResult(isValid: false, errors: [error.localizedDescription])
        }
    }

    /// Validates extracted text
    public func validateExtractedText(_ text: String) throws {
        // Check if empty
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw DocumentParserValidationError.noTextExtracted
        }

        // Check minimum length
        guard trimmedText.count >= Self.minTextLength else {
            throw DocumentParserValidationError.insufficientText(
                length: trimmedText.count,
                minimum: Self.minTextLength
            )
        }

        // Check maximum length
        guard trimmedText.count <= Self.maxTextLength else {
            throw DocumentParserValidationError.textTooLong(
                length: trimmedText.count,
                maximum: Self.maxTextLength
            )
        }

        // Check for meaningful content
        guard containsMeaningfulContent(trimmedText) else {
            throw DocumentParserValidationError.noMeaningfulContent
        }
    }

    /// Validates extracted data
    public func validateExtractedData(_ data: ExtractedData) throws {
        // Validate entities based on type
        for entity in data.entities {
            switch entity.type {
            case .vendor:
                try validateVendorName(entity.value)
            case .email:
                try validateEmail(entity.value)
            case .phone:
                try validatePhone(entity.value)
            case .partNumber:
                // Check if this might be a UEI or CAGE code
                if entity.value.count == 12, entity.value.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    try validateUEI(entity.value)
                } else if entity.value.count == 5, entity.value.allSatisfy({ $0.isLetter || $0.isNumber }) {
                    try validateCAGE(entity.value)
                }
            case .price:
                // Try to parse price from string
                let priceString = entity.value.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
                if let price = Decimal(string: priceString) {
                    try validatePrice(price)
                }
            case .date:
                // Date validation handled by document parser
                break
            default:
                break
            }
        }

        // Validate tables that contain line items
        for table in data.tables where table.headers.contains(where: { $0.lowercased().contains("price") || $0.lowercased().contains("amount") }) {
                // Extract and validate line items from table
                var lineItems: [LineItem] = []
                for row in table.rows {
                    // Simple extraction - could be improved
                    if row.count >= 2,
                       let quantity = Double(row[0]),
                       let priceString = row.last?.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: ""),
                       let unitPrice = Decimal(string: priceString) {
                        let lineItem = LineItem(
                            itemNumber: nil,
                            description: row.count > 2 ? row[1] : "Item",
                            quantity: quantity,
                            unitPrice: unitPrice,
                            totalPrice: Decimal(quantity) * unitPrice
                        )
                        lineItems.append(lineItem)
                    }
                }
                try validateLineItems(lineItems)
            }
        }
    }

    // MARK: - Private Methods

    private func isSupportedType(_ type: UniformTypeIdentifiers.UTType) -> Bool {
        // Check direct identifier match
        if DocumentParserValidator.supportedTypes.contains(type.identifier) {
            return true
        }

        // Check conformance to supported types
        if type.conforms(to: .pdf) || type.conforms(to: .text) || type.conforms(to: .image) {
            return true
        }

        // Check for Word document types
        let wordExtensions = ["doc", "docx"]
        for ext in wordExtensions {
            if let wordType = UniformTypeIdentifiers.UTType(filenameExtension: ext), type.conforms(to: wordType) {
                return true
            }
        }

        return false
    }

    private func validateDocumentStructure(_ data: Data, type: UniformTypeIdentifiers.UTType) throws {
        if type == .pdf {
            // Check PDF header
            let pdfHeader: [UInt8] = [0x25, 0x50, 0x44, 0x46] // %PDF
            guard data.count >= 4 else {
                throw DocumentParserValidationError.corruptedDocument("PDF too small")
            }

            let header = Array(data.prefix(4))
            guard header == pdfHeader else {
                throw DocumentParserValidationError.corruptedDocument("Invalid PDF header")
            }
        } else if type.conforms(to: .image) {
            // Basic image validation is handled by UIImage/NSImage initialization
            // Additional checks can be added here if needed
        }
        // Word documents are validated during parsing
    }

    private func containsMeaningfulContent(_ text: String) -> Bool {
        // Check if text contains actual words (not just numbers/symbols)
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty && $0.rangeOfCharacter(from: .letters) != nil }

        return words.count >= 3 // At least 3 words with letters
    }

    private func validateVendorName(_ name: String) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DocumentParserValidationError.invalidField("Vendor Name", "cannot be empty")
        }

        guard trimmed.count >= 2 else {
            throw DocumentParserValidationError.invalidField("Vendor Name", "too short")
        }

        guard trimmed.count <= 200 else {
            throw DocumentParserValidationError.invalidField("Vendor Name", "too long")
        }
    }

    private func validateEmail(_ email: String) throws {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)

        guard emailPredicate.evaluate(with: email) else {
            throw DocumentParserValidationError.invalidField("Email", "invalid format")
        }
    }

    private func validatePhone(_ phone: String) throws {
        // Remove common phone formatting characters
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)

        guard !cleaned.isEmpty else {
            throw DocumentParserValidationError.invalidField("Phone", "cannot be empty")
        }

        // Basic length check (international numbers can vary)
        guard cleaned.count >= 7, cleaned.count <= 20 else {
            throw DocumentParserValidationError.invalidField("Phone", "invalid length")
        }
    }

    private func validateUEI(_ uei: String) throws {
        // UEI should be exactly 12 alphanumeric characters
        let cleaned = uei.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count == 12 else {
            throw DocumentParserValidationError.invalidField("UEI", "must be 12 characters")
        }

        let alphanumericSet = CharacterSet.alphanumerics
        guard cleaned.unicodeScalars.allSatisfy({ alphanumericSet.contains($0) }) else {
            throw DocumentParserValidationError.invalidField("UEI", "must be alphanumeric")
        }
    }

    private func validateCAGE(_ cage: String) throws {
        // CAGE code should be 5 alphanumeric characters
        let cleaned = cage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.count == 5 else {
            throw DocumentParserValidationError.invalidField("CAGE", "must be 5 characters")
        }

        let alphanumericSet = CharacterSet.alphanumerics
        guard cleaned.unicodeScalars.allSatisfy({ alphanumericSet.contains($0) }) else {
            throw DocumentParserValidationError.invalidField("CAGE", "must be alphanumeric")
        }
    }

    private func validatePrice(_ price: Decimal) throws {
        guard price >= 0 else {
            throw DocumentParserValidationError.invalidField("Price", "cannot be negative")
        }

        // Check for reasonable maximum (e.g., $1 billion)
        guard price <= 1_000_000_000 else {
            throw DocumentParserValidationError.invalidField("Price", "exceeds reasonable maximum")
        }
    }

    private func validateLineItems(_ items: [LineItem]) throws {
        for (index, item) in items.enumerated() {
            // Validate description
            let trimmedDesc = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedDesc.isEmpty else {
                throw DocumentParserValidationError.invalidField(
                    "Line Item \(index + 1) Description",
                    "cannot be empty"
                )
            }

            // Validate quantity
            guard item.quantity > 0 else {
                throw DocumentParserValidationError.invalidField(
                    "Line Item \(index + 1) Quantity",
                    "must be positive"
                )
            }

            // Validate unit price
            guard item.unitPrice >= 0 else {
                throw DocumentParserValidationError.invalidField(
                    "Line Item \(index + 1) Unit Price",
                    "cannot be negative"
                )
            }

            // Validate total price
            guard item.totalPrice >= 0 else {
                throw DocumentParserValidationError.invalidField(
                    "Line Item \(index + 1) Total Price",
                    "cannot be negative"
                )
            }

            // Verify calculation if possible
            let calculatedTotal = Decimal(item.quantity) * item.unitPrice
            let tolerance: Decimal = 0.01 // Allow for rounding differences

            if abs(calculatedTotal - item.totalPrice) > tolerance {
                // This is a warning, not necessarily an error
                // Could log this for review
            }
        }
    }

    private func validateDate(_ date: Date, field: String) throws {
        let calendar = Calendar.current
        let now = Date()

        // Check if date is not too far in the past (e.g., 10 years)
        if let tenYearsAgo = calendar.date(byAdding: .year, value: -10, to: now),
           date < tenYearsAgo {
            throw DocumentParserValidationError.invalidField(
                field,
                "date is too far in the past"
            )
        }

        // Check if date is not too far in the future (e.g., 5 years)
        if let fiveYearsFromNow = calendar.date(byAdding: .year, value: 5, to: now),
           date > fiveYearsFromNow {
            throw DocumentParserValidationError.invalidField(
                field,
                "date is too far in the future"
            )
        }
    }

// MARK: - Validation Result Type

public struct DocumentValidationResult {
    public let isValid: Bool
    public let errors: [String]

    public init(isValid: Bool, errors: [String]) {
        self.isValid = isValid
        self.errors = errors
    }
}

// MARK: - Validation Error Types

public enum DocumentParserValidationError: Error, LocalizedError {
    case fileTooLarge(sizeMB: Int, maxSizeMB: Int)
    case emptyDocument
    case unsupportedDocumentType(String)
    case corruptedDocument(String)
    case noTextExtracted
    case insufficientText(length: Int, minimum: Int)
    case textTooLong(length: Int, maximum: Int)
    case noMeaningfulContent
    case invalidField(String, String)
    case invalidDateRange(String)

    public var errorDescription: String? {
        switch self {
        case let .fileTooLarge(sizeMB, maxSizeMB):
            "File too large: \(sizeMB)MB (maximum: \(maxSizeMB)MB)"
        case .emptyDocument:
            "Document is empty"
        case let .unsupportedDocumentType(type):
            "Unsupported document type: \(type)"
        case let .corruptedDocument(reason):
            "Document appears to be corrupted: \(reason)"
        case .noTextExtracted:
            "No text could be extracted from the document"
        case let .insufficientText(length, minimum):
            "Extracted text too short: \(length) characters (minimum: \(minimum))"
        case let .textTooLong(length, maximum):
            "Extracted text too long: \(length) characters (maximum: \(maximum))"
        case .noMeaningfulContent:
            "Document does not contain meaningful text content"
        case let .invalidField(field, reason):
            "\(field) is invalid: \(reason)"
        case let .invalidDateRange(reason):
            "Invalid date range: \(reason)"
        }
    }
}
