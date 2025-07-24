@testable import AppCore
import XCTest

final class UnitFormFactoryTests: XCTestCase {
    // MARK: - SF1449 Factory Tests

    func testSF1449Factory_CreateWithValidData_Success() throws {
        // Given
        let factory = SF1449Factory()
        let formData = createSF1449FormData()

        // When
        let form = try factory.create(with: formData)

        // Then
        XCTAssertEqual(form.formNumber, "SF1449")
        XCTAssertEqual(form.formTitle, "Solicitation/Contract/Order for Commercial Items")
        XCTAssertEqual(form.revision, "04/2024")
        XCTAssertTrue(form.isValid(on: Date()))

        // Verify sections
        XCTAssertNotNil(form.solicitationSection)
        XCTAssertNotNil(form.contractOrderSection)
        XCTAssertNotNil(form.scheduleSection)
        XCTAssertNotNil(form.certificationSection)
    }

    func testSF1449Factory_CreateBlank_Success() {
        // Given
        let factory = SF1449Factory()

        // When
        let form = factory.createBlank()

        // Then
        XCTAssertEqual(form.formNumber, "SF1449")
        XCTAssertEqual(form.formTitle, "Solicitation/Contract/Order for Commercial Items")
        XCTAssertTrue(form.solicitationSection.isBlank)
        XCTAssertTrue(form.contractOrderSection.isBlank)
    }

    func testSF1449Factory_ValidateData_MissingRequired_ThrowsError() {
        // Given
        let factory = SF1449Factory()
        let formData = FormData() // Empty data

        // When/Then
        XCTAssertThrowsError(try factory.validate(formData)) { error in
            guard let validationError = error as? FormValidationError,
                  case .missingRequiredField = validationError
            else {
                XCTFail("Expected FormValidationError.missingRequiredField")
                return
            }
        }
    }

    // MARK: - SF33 Factory Tests

    func testSF33Factory_CreateWithValidData_Success() throws {
        // Given
        let factory = SF33Factory()
        let formData = createSF33FormData()

        // When
        let form = try factory.create(with: formData)

        // Then
        XCTAssertEqual(form.formNumber, "SF33")
        XCTAssertEqual(form.formTitle, "Solicitation, Offer and Award")
        XCTAssertEqual(form.revision, "04/2024")

        // Verify sections
        XCTAssertNotNil(form.solicitationSection)
        XCTAssertNotNil(form.offerSection)
        XCTAssertNotNil(form.awardSection)
    }

    func testSF33Factory_CreateBlank_Success() {
        // Given
        let factory = SF33Factory()

        // When
        let form = factory.createBlank()

        // Then
        XCTAssertEqual(form.formNumber, "SF33")
        XCTAssertTrue(form.solicitationSection.isBlank)
        XCTAssertTrue(form.offerSection.isBlank)
        XCTAssertTrue(form.awardSection.isBlank)
    }

    // MARK: - SF30 Factory Tests

    func testSF30Factory_CreateWithValidData_Success() throws {
        // Given
        let factory = SF30Factory()
        let formData = createSF30FormData()

        // When
        let form = try factory.create(with: formData)

        // Then
        XCTAssertEqual(form.formNumber, "SF30")
        XCTAssertEqual(form.formTitle, "Amendment of Solicitation/Modification of Contract")
        XCTAssertEqual(form.revision, "04/2024")

        // Verify sections
        XCTAssertNotNil(form.modificationSection)
        XCTAssertNotNil(form.contractorSection)
        XCTAssertNotNil(form.changeSection)
    }

    // MARK: - SF18 Factory Tests

    func testSF18Factory_CreateWithValidData_Success() throws {
        // Given
        let factory = SF18Factory()
        let formData = createSF18FormData()

        // When
        let form = try factory.create(with: formData)

        // Then
        XCTAssertEqual(form.formNumber, "SF18")
        XCTAssertEqual(form.formTitle, "Request for Quotation")
        XCTAssertEqual(form.revision, "06/2016")

        // Verify sections
        XCTAssertNotNil(form.requestSection)
        XCTAssertNotNil(form.vendorSection)
        XCTAssertNotNil(form.quotationSection)
    }

    // MARK: - SF26 Factory Tests

    func testSF26Factory_CreateWithValidData_Success() throws {
        // Given
        let factory = SF26Factory()
        let formData = createSF26FormData()

        // When
        let form = try factory.create(with: formData)

        // Then
        XCTAssertEqual(form.formNumber, "SF26")
        XCTAssertEqual(form.formTitle, "Award/Contract")
        XCTAssertEqual(form.revision, "04/2024")

        // Verify sections
        XCTAssertNotNil(form.awardSection)
        XCTAssertNotNil(form.contractorSection)
        XCTAssertNotNil(form.itemSection)
    }

    // MARK: - SF44 Factory Tests

    func testSF44Factory_CreateWithValidData_Success() throws {
        // Given
        let factory = SF44Factory()
        let formData = createSF44FormData()

        // When
        let form = try factory.create(with: formData)

        // Then
        XCTAssertEqual(form.formNumber, "SF44")
        XCTAssertEqual(form.formTitle, "Purchase Order - Invoice - Voucher")
        XCTAssertEqual(form.revision, "10/1983")

        // Verify sections
        XCTAssertNotNil(form.orderSection)
        XCTAssertNotNil(form.vendorSection)
        XCTAssertNotNil(form.itemSection)
    }

    // MARK: - DD1155 Factory Tests

    func testDD1155Factory_CreateWithValidData_Success() throws {
        // Given
        let factory = DD1155Factory()
        let formData = createDD1155FormData()

        // When
        let form = try factory.create(with: formData)

        // Then
        XCTAssertEqual(form.formNumber, "DD1155")
        XCTAssertEqual(form.formTitle, "Order for Supplies or Services")
        XCTAssertEqual(form.revision, "06/2024")

        // Verify sections
        XCTAssertNotNil(form.orderSection)
        XCTAssertNotNil(form.vendorSection)
        XCTAssertNotNil(form.scheduleSection)
    }

    // MARK: - Registry Tests

    func testFormFactoryRegistry_RegisterAndCreate_Success() throws {
        // Given
        let registry = FormFactoryRegistry()
        let factory = SF1449Factory()
        registry.register(factory, for: "SF1449")

        let formData = createSF1449FormData()

        // When
        let form = try registry.createForm(type: "SF1449", with: formData)

        // Then
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.formNumber, "SF1449")
    }

    func testFormFactoryRegistry_CreateUnregisteredType_ReturnsNil() throws {
        // Given
        let registry = FormFactoryRegistry()
        let formData = FormData()

        // When
        let form = try registry.createForm(type: "UnknownForm", with: formData)

        // Then
        XCTAssertNil(form)
    }

    func testFormFactoryRegistry_CreateBlankForm_Success() {
        // Given
        let registry = FormFactoryRegistry()
        let factory = SF33Factory()
        registry.register(factory, for: "SF33")

        // When
        let form = registry.createBlankForm(type: "SF33")

        // Then
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.formNumber, "SF33")
    }

    // MARK: - Validation Tests

    func testFormValidation_InvalidRevision_ThrowsError() {
        // Given
        let factory = SF1449Factory()
        let formData = createSF1449FormData()
        formData["revision"] = "01/2020" // Old revision

        // When/Then
        XCTAssertThrowsError(try factory.validate(formData)) { error in
            guard let validationError = error as? FormValidationError,
                  case .invalidFieldValue = validationError
            else {
                XCTFail("Expected FormValidationError.invalidFieldValue")
                return
            }
        }
    }

    func testFormValidation_InvalidDate_ThrowsError() {
        // Given
        let factory = SF1449Factory()
        let formData = createSF1449FormData()
        formData["requisitionDate"] = "invalid-date"

        // When/Then
        XCTAssertThrowsError(try factory.validate(formData)) { error in
            guard let validationError = error as? FormValidationError,
                  case .invalidFieldValue = validationError
            else {
                XCTFail("Expected FormValidationError.invalidFieldValue")
                return
            }
        }
    }

    // MARK: - Performance Tests

    func testPerformance_CreateManyForms() {
        let factory = SF1449Factory()
        let formData = createSF1449FormData()

        measure {
            for _ in 1 ... 100 {
                _ = try? factory.create(with: formData)
            }
        }
    }

    // MARK: - Helper Methods

    private func createSF1449FormData() -> FormData {
        let data = FormData()
        data["requisitionNumber"] = "REQ-2024-001"
        data["requisitionDate"] = "2024-01-15"
        data["pageCount"] = 5
        data["solicitationNumber"] = "SOL-2024-001"
        data["solicitationDate"] = "2024-01-20"
        data["contractorName"] = "Test Company LLC"
        data["contractorAddress"] = "123 Main St, City, ST 12345"
        data["itemDescription"] = "Office Supplies"
        data["quantity"] = 100
        data["unitPrice"] = 25.50
        data["totalAmount"] = 2550.00
        data["deliveryDate"] = "2024-02-15"
        data["deliveryLocation"] = "Main Office"
        data["certificationSignature"] = "John Doe"
        data["certificationDate"] = "2024-01-20"
        data["revision"] = "04/2024"
        return data
    }

    private func createSF33FormData() -> FormData {
        let data = FormData()
        data["solicitationNumber"] = "SOL-2024-002"
        data["issuedBy"] = "Contracting Office"
        data["issueDate"] = "2024-01-15"
        data["offerorName"] = "Test Vendor Inc"
        data["offerorAddress"] = "456 Oak Ave, Town, ST 67890"
        data["offerDate"] = "2024-01-25"
        data["offerValidUntil"] = "2024-03-25"
        data["awardDate"] = "2024-02-01"
        data["awardAmount"] = 50000.00
        data["contractingOfficerName"] = "Jane Smith"
        data["contractingOfficerTitle"] = "Contracting Officer"
        data["revision"] = "04/2024"
        return data
    }

    private func createSF30FormData() -> FormData {
        let data = FormData()
        data["modificationNumber"] = "P00001"
        data["contractNumber"] = "W912QR-24-C-0001"
        data["effectiveDate"] = "2024-02-01"
        data["contractorName"] = "Test Contractor LLC"
        data["contractorCode"] = "12345"
        data["changeDescription"] = "Add additional line items"
        data["changeAmount"] = 10000.00
        data["revision"] = "04/2024"
        return data
    }

    private func createSF18FormData() -> FormData {
        let data = FormData()
        data["rfqNumber"] = "RFQ-2024-001"
        data["issueDate"] = "2024-01-10"
        data["dueDate"] = "2024-01-25"
        data["buyerName"] = "John Buyer"
        data["buyerPhone"] = "555-1234"
        data["deliveryDate"] = "2024-02-15"
        data["deliveryLocation"] = "Warehouse A"
        data["itemDescription"] = "Computer Equipment"
        data["quantity"] = 50
        data["vendorName"] = "Tech Supplies Co"
        data["vendorContact"] = "Sales Team"
        data["quotedPrice"] = 25000.00
        data["deliveryTerms"] = "FOB Destination"
        data["revision"] = "06/2016"
        return data
    }

    private func createSF26FormData() -> FormData {
        let data = FormData()
        data["contractNumber"] = "W912QR-24-C-0002"
        data["awardDate"] = "2024-01-30"
        data["effectiveDate"] = "2024-02-01"
        data["contractorName"] = "Award Winner Corp"
        data["contractorAddress"] = "789 Pine St, Village, ST 13579"
        data["contractorUEI"] = "ABCDEF123456"
        data["itemDescription"] = "Professional Services"
        data["periodStart"] = "2024-02-01"
        data["periodEnd"] = "2025-01-31"
        data["totalAmount"] = 150_000.00
        data["fundingSource"] = "Operations Budget"
        data["revision"] = "04/2024"
        return data
    }

    private func createSF44FormData() -> FormData {
        let data = FormData()
        data["orderNumber"] = "PO-2024-0001"
        data["orderDate"] = "2024-01-15"
        data["vendorName"] = "Quick Supply Inc"
        data["vendorAddress"] = "321 Elm Rd, Borough, ST 24680"
        data["shipTo"] = "Main Office Loading Dock"
        data["paymentTerms"] = "Net 30"
        data["itemDescription"] = "Office Furniture"
        data["quantity"] = 10
        data["unitPrice"] = 500.00
        data["totalAmount"] = 5000.00
        data["shippingCost"] = 250.00
        data["grandTotal"] = 5250.00
        data["revision"] = "10/1983"
        return data
    }

    private func createDD1155FormData() -> FormData {
        let data = FormData()
        data["orderNumber"] = "SPE7LX-24-D-0001"
        data["requisitionNumber"] = "REQ-DOD-2024-001"
        data["priority"] = "03 - Routine"
        data["issueDate"] = "2024-01-20"
        data["vendorName"] = "Defense Contractor LLC"
        data["vendorCAGE"] = "1ABC2"
        data["vendorAddress"] = "100 Military Way, Base, ST 99999"
        data["deliveryDate"] = "2024-03-01"
        data["shipTo"] = "Building 42, Fort Example"
        data["itemDescription"] = "Tactical Equipment"
        data["nsn"] = "5965-01-234-5678"
        data["quantity"] = 100
        data["unitPrice"] = 125.00
        data["totalPrice"] = 12500.00
        data["fundCitation"] = "97X4930.2024"
        data["authorizedBy"] = "MAJ Smith"
        data["revision"] = "06/2024"
        return data
    }
}
