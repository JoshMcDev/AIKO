import ComposableArchitecture
import Foundation

// MARK: - Smart Defaults Demo Feature

@Reducer
struct SmartDefaultsDemoFeature {
    @ObservableState
    struct State: Equatable {
        var isLoading = false
        var showingLearningDetails = false
        var context = SmartDefaultContext()
        var formFields: [SmartDefaultField] = []
        var metrics = SmartDefaultsMetrics()

        init() {
            // Empty init
        }
    }

    enum Action {
        case onAppear
        case generateNewDefaults
        case defaultsGenerated([SmartDefaultField])
        case acceptDefault(SmartDefaultField)
        case rejectDefault(SmartDefaultField)
        case editField(SmartDefaultField, String)
        case acceptAllDefaults
        case clearAllDefaults
        case showLearningDetails
        case dismissLearningDetails
        case updateMetrics
    }

    @Dependency(\.smartDefaultsEngine) var smartDefaultsEngine
    @Dependency(\.continuousClock) var clock

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .run { send in
                    await send(.generateNewDefaults)
                }

            case .generateNewDefaults:
                state.isLoading = true
                return .run { [context = state.context] send in
                    // Simulate getting smart defaults
                    try await clock.sleep(for: .seconds(1))

                    let fields = await generateSampleSmartDefaults(context: context)
                    await send(.defaultsGenerated(fields))
                }

            case let .defaultsGenerated(fields):
                state.isLoading = false
                state.formFields = fields
                return .send(.updateMetrics)

            case let .acceptDefault(field):
                if let index = state.formFields.firstIndex(where: { $0.id == field.id }) {
                    state.formFields[index].status = .autoFilled
                    state.formFields[index].userAccepted = true
                }

                // Learn from acceptance
                return .run { [field, context = state.context] _ in
                    await smartDefaultsEngine.learn(
                        field: field.fieldType,
                        suggestedValue: field.value,
                        acceptedValue: field.value,
                        wasAccepted: true,
                        context: context
                    )
                }

            case let .rejectDefault(field):
                if let index = state.formFields.firstIndex(where: { $0.id == field.id }) {
                    state.formFields[index].status = .manual
                    state.formFields[index].userAccepted = false
                }

                // Learn from rejection
                return .run { [field, context = state.context] _ in
                    await smartDefaultsEngine.learn(
                        field: field.fieldType,
                        suggestedValue: field.value,
                        acceptedValue: "",
                        wasAccepted: false,
                        context: context
                    )
                }

            case let .editField(field, newValue):
                if let index = state.formFields.firstIndex(where: { $0.id == field.id }) {
                    state.formFields[index].value = newValue
                    state.formFields[index].status = .userEdited
                }

                // Learn from edit
                return .run { [field, context = state.context] _ in
                    await smartDefaultsEngine.learn(
                        field: field.fieldType,
                        suggestedValue: field.value,
                        acceptedValue: newValue,
                        wasAccepted: false,
                        context: context
                    )
                }

            case .acceptAllDefaults:
                for index in state.formFields.indices where state.formFields[index].status == .suggested {
                    state.formFields[index].status = .autoFilled
                    state.formFields[index].userAccepted = true
                }
                return .send(.updateMetrics)

            case .clearAllDefaults:
                for index in state.formFields.indices {
                    state.formFields[index].value = ""
                    state.formFields[index].status = .manual
                    state.formFields[index].userAccepted = false
                }
                return .send(.updateMetrics)

            case .showLearningDetails:
                state.showingLearningDetails = true
                return .none

            case .dismissLearningDetails:
                state.showingLearningDetails = false
                return .none

            case .updateMetrics:
                state.metrics.autoFillCount = state.formFields.count(where: { $0.status == .autoFilled })
                state.metrics.suggestedCount = state.formFields.count(where: { $0.status == .suggested })
                state.metrics.manualCount = state.formFields.count(where: { $0.status == .manual })
                state.metrics.learningProgress = Float(state.metrics.autoFillCount) / Float(max(state.formFields.count, 1))
                return .none
            }
        }
    }
}

// MARK: - Supporting Types

struct SmartDefaultField: Equatable, Identifiable {
    let id = UUID()
    let fieldType: RequirementField
    let name: String
    var value: String
    var confidence: Float
    var status: Status
    var reasoning: String?
    var alternatives: [String]
    var userAccepted: Bool = false

    enum Status: Equatable {
        case autoFilled
        case suggested
        case manual
        case userEdited
    }
}

struct SmartDefaultsMetrics: Equatable {
    var autoFillCount: Int = 0
    var suggestedCount: Int = 0
    var manualCount: Int = 0
    var learningProgress: Float = 0.0
}

// MARK: - Sample Data Generation

private func generateSampleSmartDefaults(context _: SmartDefaultContext) async -> [SmartDefaultField] {
    [
        SmartDefaultField(
            fieldType: .vendorName,
            name: "Vendor Name",
            value: "Acme Office Supplies Inc.",
            confidence: 0.92,
            status: .autoFilled,
            reasoning: "Most frequently used vendor (15 times)",
            alternatives: ["Office Depot", "Staples Business"]
        ),
        SmartDefaultField(
            fieldType: .requiredDate,
            name: "Required Delivery Date",
            value: "02/15/2025",
            confidence: 0.85,
            status: .suggested,
            reasoning: "Standard 30-day delivery window",
            alternatives: ["02/28/2025", "03/15/2025"]
        ),
        SmartDefaultField(
            fieldType: .fundingSource,
            name: "Funding Source",
            value: "O&M FY2025",
            confidence: 0.95,
            status: .autoFilled,
            reasoning: "Based on acquisition type and fiscal year",
            alternatives: ["Services FY2025"]
        ),
        SmartDefaultField(
            fieldType: .performanceLocation,
            name: "Delivery Location",
            value: "Building 123, Room 456",
            confidence: 0.88,
            status: .suggested,
            reasoning: "Your department's default location",
            alternatives: ["Central Warehouse", "Building 789"]
        ),
        SmartDefaultField(
            fieldType: .estimatedValue,
            name: "Estimated Value",
            value: "$25,000",
            confidence: 0.75,
            status: .suggested,
            reasoning: "Average purchase amount for office supplies",
            alternatives: ["$15,000", "$35,000"]
        ),
        SmartDefaultField(
            fieldType: .contractType,
            name: "Contract Type",
            value: "Purchase Order",
            confidence: 0.90,
            status: .autoFilled,
            reasoning: "Standard for purchases under SAT",
            alternatives: ["BPA Call", "Fixed Price"]
        ),
        SmartDefaultField(
            fieldType: .justification,
            name: "Justification",
            value: "",
            confidence: 0.0,
            status: .manual,
            reasoning: "Requires specific input",
            alternatives: []
        ),
        SmartDefaultField(
            fieldType: .pointOfContact,
            name: "Point of Contact",
            value: "John Smith, x1234",
            confidence: 0.82,
            status: .suggested,
            reasoning: "Your usual POC for supplies",
            alternatives: ["Jane Doe, x5678"]
        ),
    ]
}

// MARK: - Dependencies

extension DependencyValues {
    var smartDefaultsEngine: SmartDefaultsEngine {
        get { self[SmartDefaultsEngineKey.self] }
        set { self[SmartDefaultsEngineKey.self] = newValue }
    }
}

private enum SmartDefaultsEngineKey: DependencyKey {
    static var liveValue: SmartDefaultsEngine {
        SmartDefaultsEngine.createForDependency()
    }
}
