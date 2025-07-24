import Foundation
import os
import OSLog

/// Memory monitoring service for AIKO GraphRAG system
/// Monitors system memory usage to coordinate LFM2-700M and SLM model coexistence
actor MemoryMonitor {
    // MARK: - Properties

    var currentMemoryStatus: MemoryStatus
    var isMonitoring: Bool = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.aiko.graphrag", category: "MemoryMonitor")
    private var monitoringTask: Task<Void, Never>?
    private let updateInterval: TimeInterval = 2.0 // Monitor every 2 seconds

    // Memory thresholds
    private let criticalMemoryThreshold: Double = 0.95 // 95% memory usage
    private let warningMemoryThreshold: Double = 0.85 // 85% memory usage
    private let safeMemoryThreshold: Double = 0.70 // 70% memory usage
    
    // Logging state
    private var lastLogTime = Date.distantPast
    private var lastMemoryPressure: MemoryPressure = .normal

    // MARK: - Initialization

    init() {
        currentMemoryStatus = MemoryStatus(
            totalMemory: ProcessInfo.processInfo.physicalMemory,
            availableMemory: 0,
            usedMemory: 0,
            appMemoryUsage: 0,
            memoryPressure: .normal,
            canPerformInference: true,
            lastUpdated: Date()
        )

        logger.info("🔍 MemoryMonitor initialized")
    }

    deinit {
        // Cannot call async method from deinit
        // Memory monitoring will be cleaned up automatically
    }

    // MARK: - Public Interface

    /// Start continuous memory monitoring
    func startMonitoring() async {
        guard !isMonitoring else {
            logger.info("MemoryMonitor already running")
            return
        }

        logger.info("🚀 Starting memory monitoring (interval: \(self.updateInterval)s)")
        isMonitoring = true

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.updateMemoryStatus()

                do {
                    try await Task.sleep(nanoseconds: UInt64(self?.updateInterval ?? 2.0 * 1_000_000_000))
                } catch {
                    // Task was cancelled
                    break
                }
            }
        }
    }

    /// Stop memory monitoring
    func stopMonitoring() {
        logger.info("🛑 Stopping memory monitoring")

        monitoringTask?.cancel()
        monitoringTask = nil
        isMonitoring = false
    }

    /// Get current memory status (immediate read)
    func checkMemoryStatus() async -> MemoryStatus {
        await updateMemoryStatus()
        return currentMemoryStatus
    }

    /// Get available memory in bytes
    func getAvailableMemory() async -> Int64 {
        let status = await checkMemoryStatus()
        return status.availableMemory
    }

    /// Check if memory conditions allow for SLM inference
    func canPerformSLMInference() async -> Bool {
        let status = await checkMemoryStatus()
        return status.canPerformInference && status.memoryPressure != .critical
    }

    /// Get memory usage percentage (0.0 to 1.0)
    func getMemoryUsagePercentage() async -> Double {
        let status = await checkMemoryStatus()
        return Double(status.usedMemory) / Double(status.totalMemory)
    }

    // MARK: - Private Implementation

    private func updateMemoryStatus() async {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let appMemoryUsage = getAppMemoryUsage()

        // Get system memory information
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        let usedMemory: Int64
        let availableMemory: Int64

        if kerr == KERN_SUCCESS {
            usedMemory = Int64(info.resident_size)
            availableMemory = Int64(totalMemory) - usedMemory
        } else {
            // Fallback to estimates if system call fails
            usedMemory = Int64(appMemoryUsage)
            availableMemory = Int64(totalMemory) - usedMemory

            logger.warning("⚠️ Failed to get accurate system memory info, using estimates")
        }

        // Calculate memory pressure
        let usagePercentage = Double(usedMemory) / Double(totalMemory)
        let memoryPressure = calculateMemoryPressure(usagePercentage: usagePercentage)

        // Determine if inference is safe
        let canPerformInference = determineInferenceCapability(
            usagePercentage: usagePercentage,
            availableMemory: availableMemory,
            memoryPressure: memoryPressure
        )

        let newStatus = MemoryStatus(
            totalMemory: totalMemory,
            availableMemory: availableMemory,
            usedMemory: usedMemory,
            appMemoryUsage: appMemoryUsage,
            memoryPressure: memoryPressure,
            canPerformInference: canPerformInference,
            lastUpdated: Date()
        )

        // Update on main actor
        currentMemoryStatus = newStatus

        // Log significant changes
        logMemoryChanges(newStatus: newStatus, usagePercentage: usagePercentage)
    }

    private func getAppMemoryUsage() -> Int64 {
        let MACH_TASK_BASIC_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.size / MemoryLayout<integer_t>.size)

        var info = mach_task_basic_info_data_t()
        var count = MACH_TASK_BASIC_INFO_COUNT

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            logger.warning("⚠️ Failed to get app memory usage")
            return 0
        }
    }

    private func calculateMemoryPressure(usagePercentage: Double) -> MemoryPressure {
        switch usagePercentage {
        case 0 ..< safeMemoryThreshold:
            .normal
        case safeMemoryThreshold ..< warningMemoryThreshold:
            .moderate
        case warningMemoryThreshold ..< criticalMemoryThreshold:
            .high
        default:
            .critical
        }
    }

    private func determineInferenceCapability(
        usagePercentage: Double,
        availableMemory: Int64,
        memoryPressure: MemoryPressure
    ) -> Bool {
        // Minimum required memory for safe SLM operation (500MB buffer)
        let minimumRequiredMemory: Int64 = 500 * 1024 * 1024

        // Don't allow inference if:
        // 1. Memory pressure is critical
        // 2. Available memory is below minimum
        // 3. Usage percentage is too high

        let hasEnoughMemory = availableMemory >= minimumRequiredMemory
        let usageIsAcceptable = usagePercentage < criticalMemoryThreshold
        let pressureIsAcceptable = memoryPressure != .critical

        return hasEnoughMemory && usageIsAcceptable && pressureIsAcceptable
    }

    private func logMemoryChanges(newStatus: MemoryStatus, usagePercentage: Double) {
        // Only log on significant changes or periodically

        let now = Date()
        let timeSinceLastLog = now.timeIntervalSince(lastLogTime)
        let pressureChanged = newStatus.memoryPressure != lastMemoryPressure

        // Log every 30 seconds or on pressure changes
        if pressureChanged || timeSinceLastLog >= 30.0 {
            let availableGB = Double(newStatus.availableMemory) / 1024 / 1024 / 1024
            let usedGB = Double(newStatus.usedMemory) / 1024 / 1024 / 1024
            let totalGB = Double(newStatus.totalMemory) / 1024 / 1024 / 1024

            logger.info("📊 Memory Status: \(String(format: "%.1f", usedGB))GB used / \(String(format: "%.1f", totalGB))GB total (\(String(format: "%.1f", usagePercentage * 100))%) | Available: \(String(format: "%.1f", availableGB))GB | Pressure: \(newStatus.memoryPressure.rawValue) | Inference: \(newStatus.canPerformInference ? "✅" : "❌")")

            lastLogTime = now
            lastMemoryPressure = newStatus.memoryPressure
        }

        // Always log critical pressure changes
        if newStatus.memoryPressure == .critical, lastMemoryPressure != .critical {
            logger.error("🚨 CRITICAL MEMORY PRESSURE - SLM inference disabled")
        } else if newStatus.memoryPressure != .critical, lastMemoryPressure == .critical {
            logger.info("✅ Memory pressure normalized - SLM inference re-enabled")
        }
    }
}

// MARK: - Supporting Types

/// Memory status information
struct MemoryStatus: Sendable {
    let totalMemory: UInt64 // Total system RAM
    let availableMemory: Int64 // Currently available memory
    let usedMemory: Int64 // Currently used memory
    let appMemoryUsage: Int64 // This app's memory usage
    let memoryPressure: MemoryPressure
    let canPerformInference: Bool // Safe to run SLM inference
    let lastUpdated: Date

    /// Memory usage as a percentage (0.0 to 1.0)
    var usagePercentage: Double {
        Double(usedMemory) / Double(totalMemory)
    }

    /// Available memory in GB
    var availableGB: Double {
        Double(availableMemory) / 1024 / 1024 / 1024
    }

    /// Used memory in GB
    var usedGB: Double {
        Double(usedMemory) / 1024 / 1024 / 1024
    }

    /// Total memory in GB
    var totalGB: Double {
        Double(totalMemory) / 1024 / 1024 / 1024
    }
}

/// Memory pressure levels
enum MemoryPressure: String, Sendable, CaseIterable {
    case normal = "Normal" // < 70% usage
    case moderate = "Moderate" // 70-85% usage
    case high = "High" // 85-95% usage
    case critical = "Critical" // > 95% usage

    var color: String {
        switch self {
        case .normal: "🟢"
        case .moderate: "🟡"
        case .high: "🟠"
        case .critical: "🔴"
        }
    }

    var description: String {
        switch self {
        case .normal: "Memory usage is within normal parameters"
        case .moderate: "Memory usage is elevated but manageable"
        case .high: "Memory usage is high - consider freeing resources"
        case .critical: "Memory usage is critical - immediate action required"
        }
    }
}
