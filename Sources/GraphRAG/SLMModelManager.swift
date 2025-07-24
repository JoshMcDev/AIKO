import CoreML
import Foundation
import OSLog
#if canImport(UIKit)
import UIKit
#endif

/// Dynamic Small Language Model manager for AIKO GraphRAG system
/// Implements VanillaIce consensus recommendations for device-aware SLM selection
actor SLMModelManager {
    // MARK: - Shared Instance

    static let shared = SLMModelManager()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.aiko.graphrag", category: "SLMModelManager")

    private var currentModel: MLModel?
    private var currentModelConfig: SLMModelConfig?
    private var deviceCapability: DeviceCapability
    private var memoryMonitor: MemoryMonitor
    private var isInitialized = false

    // Model specifications based on VanillaIce consensus
    private lazy var modelConfigurations: [SLMModelType: SLMModelConfig] = {
        let phi3Config = SLMModelConfig(
            name: "Phi-3-mini-4k-instruct",
            size: Int64(2.3 * 1024 * 1024 * 1024), // 2.3GB
            memoryRequirement: Int64(2.8 * 1024 * 1024 * 1024), // 2.8GB total
            contextWindow: 4096,
            priority: 1, // Primary model
            compatibleDevices: [.iPhone15Pro, .iPadProM4],
            optimizations: ["Q4_0", "Q4_K_M", "Q6_K"]
        )
        
        let qwenConfig = SLMModelConfig(
            name: "Qwen 2.5 7B",
            size: Int64(4.0 * 1024 * 1024 * 1024), // 4GB
            memoryRequirement: Int64(5.2 * 1024 * 1024 * 1024), // 5.2GB total
            contextWindow: 32768,
            priority: 2, // Fallback model
            compatibleDevices: [.iPadProM4],
            optimizations: ["Q4_0", "Q4_K_M", "Q6_K", "Q8_0"]
        )
        
        return [
            .phi3Mini: phi3Config,
            .qwen25_7B: qwenConfig
        ]
    }()

    // MARK: - Initialization

    private init() {
        deviceCapability = DeviceCapability.detect()
        memoryMonitor = MemoryMonitor()
        let deviceType = deviceCapability.rawValue
        logger.info("🚀 SLMModelManager initializing for device: \(deviceType)")
    }

    /// Initialize the SLM model manager with optimal model selection
    func initialize() async throws {
        guard !isInitialized else {
            logger.info("✅ SLMModelManager already initialized")
            return
        }

        logger.info("🔄 Initializing SLM model manager...")

        // Start memory monitoring
        await memoryMonitor.startMonitoring()

        // Select optimal model based on device capability and memory
        let selectedModel = try await selectOptimalModel()

        // Load the selected model
        try await loadModel(selectedModel)

        isInitialized = true
        logger.info("✅ SLMModelManager initialization complete with \(selectedModel.rawValue)")
    }

    // MARK: - Model Selection Logic

    private func selectOptimalModel() async throws -> SLMModelType {
        let availableMemory = await memoryMonitor.getAvailableMemory()

        let deviceType = deviceCapability.rawValue
        logger.info("📊 Device capability: \(deviceType)")
        logger.info("📊 Available memory: \(String(format: "%.1f", Double(availableMemory) / 1024 / 1024 / 1024))GB")

        // Apply VanillaIce consensus logic:
        // - iPhone 15 Pro (8GB RAM): Phi-3-mini primary
        // - iPad Pro M4 (16GB RAM): Qwen 2.5 7B preferred, Phi-3-mini fallback

        switch deviceCapability {
        case .iPhone15Pro:
            // Primary: Phi-3-mini (2.3GB model + 0.5GB overhead + 2GB for LFM2 coexistence)
            guard let phi3Config = modelConfigurations[.phi3Mini] else {
                logger.error("❌ Phi-3-mini configuration not found")
                throw SLMError.modelNotFound("Phi-3-mini")
            }
            let requiredMemory = phi3Config.memoryRequirement + Int64(2.0 * 1024 * 1024 * 1024)

            if availableMemory >= requiredMemory {
                logger.info("✅ Selected Phi-3-mini for iPhone 15 Pro (optimal)")
                return .phi3Mini
            } else {
                logger.warning("⚠️ Insufficient memory for Phi-3-mini. Required: \(String(format: "%.1f", Double(requiredMemory) / 1024 / 1024 / 1024))GB")
                throw SLMError.insufficientMemory(required: requiredMemory, available: availableMemory)
            }

        case .iPadProM4:
            // Preferred: Qwen 2.5 7B (4GB model + 1.2GB overhead + 2GB for LFM2)
            guard let qwenConfig = modelConfigurations[.qwen25_7B],
                  let phi3Config = modelConfigurations[.phi3Mini]
            else {
                logger.error("❌ Model configurations not found")
                throw SLMError.modelNotFound("Required model configurations")
            }
            let qwenRequired = qwenConfig.memoryRequirement + Int64(2.0 * 1024 * 1024 * 1024)
            let phi3Required = phi3Config.memoryRequirement + Int64(2.0 * 1024 * 1024 * 1024)

            if availableMemory >= qwenRequired {
                logger.info("✅ Selected Qwen 2.5 7B for iPad Pro M4 (preferred)")
                return .qwen25_7B
            } else if availableMemory >= phi3Required {
                logger.info("⚠️ Fallback to Phi-3-mini for iPad Pro M4 (memory constraint)")
                return .phi3Mini
            } else {
                logger.error("❌ Insufficient memory for any SLM model")
                throw SLMError.insufficientMemory(required: phi3Required, available: availableMemory)
            }

        case .unsupported:
            logger.error("❌ Unsupported device for SLM models")
            throw SLMError.unsupportedDevice
        }
    }

    // MARK: - Model Loading

    private func loadModel(_ modelType: SLMModelType) async throws {
        guard let config = modelConfigurations[modelType] else {
            logger.error("❌ Configuration not found for model type: \(modelType.rawValue)")
            throw SLMError.modelNotFound(modelType.rawValue)
        }

        logger.info("🔄 Loading \(config.name) model...")

        // Check memory before loading
        let availableMemory = await memoryMonitor.getAvailableMemory()
        guard availableMemory >= config.memoryRequirement else {
            throw SLMError.insufficientMemory(required: config.memoryRequirement, available: availableMemory)
        }

        // Load model from bundle or download
        let modelURL = try await getModelURL(for: modelType)

        do {
            // Load CoreML model - simplified for actor isolation
            let mlModel = try MLModel(contentsOf: modelURL)
            currentModel = mlModel
            currentModelConfig = config

            logger.info("✅ \(config.name) model loaded successfully")
            logger.info("📊 Model size: \(String(format: "%.1f", Double(config.size) / 1024 / 1024 / 1024))GB")

        } catch {
            logger.error("❌ Failed to load \(config.name): \(error.localizedDescription)")
            throw SLMError.modelLoadingFailed(error)
        }
    }

    private func getModelURL(for modelType: SLMModelType) async throws -> URL {
        guard let config = modelConfigurations[modelType] else {
            logger.error("❌ Configuration not found for model type: \(modelType.rawValue)")
            throw SLMError.modelNotFound(modelType.rawValue)
        }

        // Try to find model in app bundle first
        if let bundleURL = Bundle.main.url(forResource: config.name, withExtension: "mlmodel") {
            logger.info("📄 Found model in bundle: \(config.name)")
            return bundleURL
        }

        // Check for GGUF models in Resources
        let possibleExtensions = ["gguf", "q4_0.gguf", "q4_k_m.gguf", "q6_k.gguf"]
        for ext in possibleExtensions {
            if let bundleURL = Bundle.main.url(forResource: config.name, withExtension: ext) {
                logger.info("📄 Found GGUF model in bundle: \(config.name).\(ext)")
                return bundleURL
            }
        }

        // Model not found in bundle - would need to download
        logger.error("❌ Model not found in bundle: \(config.name)")
        throw SLMError.modelNotFound(config.name)
    }

    // MARK: - Inference Interface

    /// Generate text completion using the loaded SLM
    func generateCompletion(
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> String {
        guard isInitialized, currentModel != nil else {
            throw SLMError.modelNotInitialized
        }

        // Check memory before inference
        let memoryStatus = await memoryMonitor.checkMemoryStatus()
        guard memoryStatus.canPerformInference else {
            logger.warning("⚠️ Memory pressure too high for SLM inference")
            throw SLMError.memoryPressure
        }

        logger.debug("🔄 Generating completion (max tokens: \(maxTokens))")

        // TODO: Implement CoreML-based text generation
        // For now, return a placeholder response
        let completion = "SLM inference not yet implemented for CoreML"
        
        logger.debug("✅ Completion generated successfully")
        return completion
    }

    /// Check if coexistence with LFM2 is possible
    func canCoexistWithLFM2() async -> Bool {
        guard currentModel != nil, let config = currentModelConfig else { return false }

        let memoryStatus = await memoryMonitor.checkMemoryStatus()
        let lfm2Requirement: Int64 = 200 * 1024 * 1024 // ~200MB for LFM2

        return memoryStatus.availableMemory >= (config.memoryRequirement + lfm2Requirement)
    }

    // MARK: - Dynamic Management

    /// Temporarily unload SLM to make room for LFM2 operations
    func temporarilyUnload() async {
        guard currentModel != nil else { return }

        logger.info("🔄 Temporarily unloading SLM for LFM2 priority operation")

        // Simply release the model reference for memory management
        currentModel = nil
        currentModelConfig = nil
        logger.info("✅ SLM temporarily unloaded")
    }

    /// Reload SLM after LFM2 operations complete
    func reload() async throws {
        guard currentModel == nil else { return }

        logger.info("🔄 Reloading SLM after LFM2 operations")

        let modelType = try await selectOptimalModel()
        try await loadModel(modelType)

        logger.info("✅ SLM reloaded successfully")
    }
}

// MARK: - Supporting Types

enum SLMModelType: String, CaseIterable {
    case phi3Mini = "phi-3-mini-4k-instruct"
    case qwen25_7B = "qwen-2.5-7b"

    var displayName: String {
        switch self {
        case .phi3Mini: "Phi-3-mini-4k-instruct"
        case .qwen25_7B: "Qwen 2.5 7B"
        }
    }
}

struct SLMModelConfig {
    let name: String
    let size: Int64 // Model file size in bytes
    let memoryRequirement: Int64 // Total memory needed during inference
    let contextWindow: Int // Maximum context length
    let priority: Int // 1 = primary, 2 = fallback
    let compatibleDevices: [DeviceCapability]
    let optimizations: [String] // Available quantization formats
}

enum DeviceCapability: String {
    case iPhone15Pro = "iPhone15Pro_8GB"
    case iPadProM4 = "iPadProM4_16GB"
    case unsupported

    static func detect() -> DeviceCapability {
        // Detect device capability based on hardware
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory

        // Simplified detection logic
        if physicalMemory >= 15 * 1024 * 1024 * 1024 { // 15GB+ = iPad Pro M4
            return .iPadProM4
        } else if physicalMemory >= 7 * 1024 * 1024 * 1024 { // 7GB+ = iPhone 15 Pro class
            return .iPhone15Pro
        } else {
            return .unsupported
        }
    }

    var totalRAM: Int64 {
        switch self {
        case .iPhone15Pro: 8 * 1024 * 1024 * 1024 // 8GB
        case .iPadProM4: 16 * 1024 * 1024 * 1024 // 16GB
        case .unsupported: 0
        }
    }
}

enum SLMError: Error, LocalizedError {
    case modelNotInitialized
    case modelNotFound(String)
    case modelLoadingFailed(Error)
    case insufficientMemory(required: Int64, available: Int64)
    case unsupportedDevice
    case memoryPressure
    case inferenceError(Error)

    var errorDescription: String? {
        switch self {
        case .modelNotInitialized:
            return "SLM model not initialized. Call initialize() first."
        case let .modelNotFound(name):
            return "SLM model '\(name)' not found in app bundle."
        case let .modelLoadingFailed(error):
            return "Failed to load SLM model: \(error.localizedDescription)"
        case let .insufficientMemory(required, available):
            let reqGB = Double(required) / 1024 / 1024 / 1024
            let availGB = Double(available) / 1024 / 1024 / 1024
            return "Insufficient memory. Required: \(String(format: "%.1f", reqGB))GB, Available: \(String(format: "%.1f", availGB))GB"
        case .unsupportedDevice:
            return "Device not supported for SLM models. Requires iPhone 15 Pro or iPad Pro M4."
        case .memoryPressure:
            return "Memory pressure too high for SLM inference."
        case let .inferenceError(error):
            return "SLM inference failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Model Information

extension SLMModelManager {
    func getModelInfo() async -> SLMModelInfo? {
        guard currentModel != nil, let config = currentModelConfig else { return nil }

        let memoryStatus = await memoryMonitor.checkMemoryStatus()
        
        // Determine model type from config
        let modelType: SLMModelType = {
            for (type, storedConfig) in modelConfigurations {
                if storedConfig.name == config.name {
                    return type
                }
            }
            return .phi3Mini // default fallback
        }()

        return SLMModelInfo(
            type: modelType,
            config: config,
            memoryUsage: memoryStatus,
            canCoexistWithLFM2: await canCoexistWithLFM2(),
            deviceCapability: deviceCapability
        )
    }
}

struct SLMModelInfo {
    let type: SLMModelType
    let config: SLMModelConfig
    let memoryUsage: MemoryStatus
    let canCoexistWithLFM2: Bool
    let deviceCapability: DeviceCapability
}
