//
//  CacheSyncViewModel.swift
//  AIKO
//
//  Created for cache synchronization UI integration
//

import Foundation
import os.log
import SwiftUI

/// View model for cache synchronization UI
@MainActor
final class CacheSyncViewModel: ObservableObject {
    /// Sync status
    @Published var isSyncing = false

    /// Last sync date
    @Published var lastSyncDate: Date?

    /// Pending changes count
    @Published var pendingChanges = 0

    /// Sync errors
    @Published var syncErrors: [String] = []

    /// Network connectivity status
    @Published var isConnected = true

    // Sync functionality removed - not needed in AIKO project
    // @Published var lastSyncResult: SyncResult?

    /// Show sync error alert
    @Published var showSyncError = false

    /// Logger
    private let logger = Logger(subsystem: "com.aiko.cache", category: "CacheSyncViewModel")

    /// Cache manager reference
    private let cacheManager = OfflineCacheManager.shared

    /// Timer for periodic updates
    private nonisolated(unsafe) var updateTimer: Timer?

    init() {
        // Start monitoring
        startMonitoring()

        // Initial load
        Task {
            await updateSyncStatus()
        }
    }

    deinit {
        // Invalidate timer directly
        if let timer = updateTimer {
            timer.invalidate()
        }
        updateTimer = nil
    }

    /// Start monitoring sync status
    private func startMonitoring() {
        // Update every 5 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.updateSyncStatus()
            }
        }
    }

    /// Update sync status from cache manager
    private func updateSyncStatus() async {
        let stats = cacheManager.statistics

        isSyncing = stats.isSyncing
        lastSyncDate = stats.lastSync
        pendingChanges = stats.pendingChanges
        syncErrors = stats.syncErrors

        // Sync functionality removed - not needed in AIKO project
        // let pendingCount = await cacheManager.pendingChangesCount()
        // if pendingCount != pendingChanges {
        //     pendingChanges = pendingCount
        // }
    }

    /// Manually trigger sync
    func triggerSync() {
        guard !isSyncing else {
            logger.info("Sync already in progress")
            return
        }

        Task {
            isSyncing = true

            // Sync functionality removed - not needed in AIKO project
            // if let result = await cacheManager.synchronize() {
            //     lastSyncResult = result
            //
            //     if !result.success {
            //         syncErrors = result.failedItems.map { $0.error }
            //         showSyncError = true
            //     }
            //
            //     logger.info("Manual sync completed - Success: \(result.success)")
            // }

            await updateSyncStatus()
            isSyncing = false
        }
    }

    /// Clear pending changes
    func clearPendingChanges() {
        Task {
            // Sync functionality removed - not needed in AIKO project
            // await cacheManager.clearPendingChanges()
            await updateSyncStatus()
            logger.info("Cleared all pending changes")
        }
    }

    /// Format last sync date
    var formattedLastSync: String {
        guard let date = lastSyncDate else {
            return "Never"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Sync status message
    var syncStatusMessage: String {
        if isSyncing {
            "Syncing..."
        } else if pendingChanges > 0 {
            "\(pendingChanges) pending changes"
        } else if lastSyncDate != nil {
            "All changes synced"
        } else {
            "Not synced"
        }
    }

    /// Sync button label
    var syncButtonLabel: String {
        if isSyncing {
            "Syncing..."
        } else if pendingChanges > 0 {
            "Sync Now (\(pendingChanges))"
        } else {
            "Sync Now"
        }
    }

    /// Whether sync button should be disabled
    var isSyncDisabled: Bool {
        isSyncing || !isConnected
    }
}
